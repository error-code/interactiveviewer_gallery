library interactiveviewer_gallery;
import 'package:flutter/material.dart';
import './custom_dismissible.dart';
import './interactive_viewer_boundary.dart';

/// 为推文媒体源构建一个由 [PageView] 控制的轮播。
///
/// 用于显示 [TweetMedia] 源的全屏视图。
///
/// 可以使用 [InteractiveViewer] 交互地平移和缩放源。
/// [InteractiveViewerBoundary] 用于检测放大后何时触及源边界以禁用或启用 [PageView] 的滑动手势。
///
typedef IndexedFocusedWidgetBuilder = Widget Function(BuildContext context, int index, bool isFocus);

typedef IndexedTagStringBuilder = String Function(int index);

class InteractiveviewerGallery<T> extends StatefulWidget {
  const InteractiveviewerGallery({
    required this.sources,
    required this.initIndex,
    required this.itemBuilder,
    this.maxScale = 2.5,
    this.minScale = 1.0,
    this.onPageChanged,
  });

  /// 要显示的来源。
  final List<T> sources;

  /// [sources] 中要显示的第一个源的索引。
  final int initIndex;

  /// 项目内容
  final IndexedFocusedWidgetBuilder itemBuilder;

  final double maxScale;

  final double minScale;

  final ValueChanged<int>? onPageChanged;


  @override
  _TweetSourceGalleryState createState() => _TweetSourceGalleryState();
}

class _TweetSourceGalleryState extends State<InteractiveviewerGallery> with SingleTickerProviderStateMixin {
  PageController? _pageController;
  TransformationController? _transformationController;

  /// 控制器在 [InteractiveViewer] 的变换值应重置时对其进行动画处理。
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  /// `true` 当源被放大并且不在水平边界处以禁用 [PageView] 时。
  bool _enablePageView = true;

  /// `true` 当源被放大以禁用 [Custom Dismissible] 时。
  bool _enableDismiss = true;

  late Offset _doubleTapLocalPosition;

  int? currentIndex;

  ///当前缩放
  double nowScale = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: widget.initIndex);

    _transformationController = TransformationController();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )
      ..addListener(() {
        _transformationController!.value = _animation?.value ?? Matrix4.identity();
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && !_enableDismiss) {
          setState(() {
            _enableDismiss = true;
          });
        }
      });

    currentIndex = widget.initIndex;
    nowScale = widget.minScale;
  }

  @override
  void dispose() {
    _pageController!.dispose();
    _animationController.dispose();

    super.dispose();
  }

  ///当开始缩放
  void _onScaleStart(){
    setState(() {
      _enableDismiss = false;
    });
  }

  /// 当源放大时，向上/向下滑动以关闭将被禁用。
  ///
  /// 当比例重置时，将启用关闭和页面视图滑动。
  void _onScaleChanged(double scale) {
    final bool initialScale = scale <= widget.minScale;
    nowScale = scale;
    print(scale);
    if (initialScale) {
      if (!_enableDismiss) {
        _enableDismiss = true;
      }

      if (!_enablePageView) {
        _enablePageView = true;
      }
    } else {
      if (_enableDismiss) {
        _enableDismiss = false;
      }

      if (_enablePageView) {
        _enablePageView = false;
      }
    }
    setState((){});
  }

  /// 放大源后击中左边界时, 如果它有要滑动到的页面，则会启用此页面视图滑动。
  void _onLeftBoundaryHit() {
    final bool canScroll = nowScale <= widget.minScale;
    print('左边界 $canScroll');
    if(!canScroll){
      setState(() {
        _enablePageView = false;
      });
      return;
    }
    if (!_enablePageView && _pageController!.page!.floor() > 0) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// 在放大源后点击右边界时，如果页面有要滑动到的页面，则会启用页面视图滑动。
  void _onRightBoundaryHit() {
    final bool canScroll = nowScale <= widget.minScale;
    print('右边界 $canScroll');
    if(!canScroll){
      setState(() {
        _enablePageView = false;
      });
      return;
    }
    if (!_enablePageView && _pageController!.page!.floor() < widget.sources.length - 1) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// 当源已按比例放大且未触及水平边界时，页面视图滑动将被禁用。
  void _onNoBoundaryHit() {
    print('_onNoBoundaryHit');
    if (_enablePageView) {
      setState(() {
        _enablePageView = false;
      });
    }
  }

  /// 当页面视图更改其页面时，如果按比例放大，源将动画回原始比例。
  ///
  /// 此外，启用了向上/向下滑动以关闭。
  void _onPageChanged(int page) {
    setState(() {
      currentIndex = page;
    });
    widget.onPageChanged?.call(page);
    if (_transformationController!.value != Matrix4.identity()) {
      // animate the reset for the transformation of the interactive viewer

      _animation = Matrix4Tween(
        begin: _transformationController!.value,
        end: Matrix4.identity(),
      ).animate(
        CurveTween(curve: Curves.easeOut).animate(_animationController),
      );
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewerBoundary(
      controller: _transformationController,
      boundaryWidth: MediaQuery.of(context).size.width,
      onScaleStart: _onScaleStart,
      onScaleChanged: _onScaleChanged,
      onLeftBoundaryHit: _onLeftBoundaryHit,
      onRightBoundaryHit: _onRightBoundaryHit,
      onNoBoundaryHit: _onNoBoundaryHit,
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      child: Container(
        color: Colors.black,
        child: PageView.builder(
          onPageChanged: _onPageChanged,
          controller: _pageController,
          physics: _enablePageView ? null : const NeverScrollableScrollPhysics(),
          itemCount: widget.sources.length,
          itemBuilder: (BuildContext context, int index) {
            return GestureDetector(
              onDoubleTapDown: (TapDownDetails details) {
                _doubleTapLocalPosition = details.localPosition;
              },
              onDoubleTap: onDoubleTap,
              child: widget.itemBuilder(context, index, index == currentIndex),
            );
          },
        ),
      ),
    );
  }

  onDoubleTap() {
    Matrix4 matrix = _transformationController!.value.clone();
    double currentScale = matrix.row0.x;

    double targetScale = widget.minScale;

    if (currentScale <= widget.minScale) {
      targetScale = widget.maxScale * 0.7;
    }

    double offSetX = targetScale == 1.0 ? 0.0 : - _doubleTapLocalPosition.dx * (targetScale - 1);
    double offSetY = targetScale == 1.0 ? 0.0 : - _doubleTapLocalPosition.dy * (targetScale - 1);

    matrix = Matrix4.fromList([targetScale, matrix.row1.x, matrix.row2.x, matrix.row3.x, matrix.row0.y, targetScale, matrix.row2.y, matrix.row3.y, matrix.row0.z, matrix.row1.z, targetScale, matrix.row3.z, offSetX, offSetY, matrix.row2.w, matrix.row3.w]);

    _animation = Matrix4Tween(
      begin: _transformationController!.value,
      end: matrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0).whenComplete(() => _onScaleChanged(targetScale));
  }
}

class CustomDismissible2 extends StatefulWidget {
  const CustomDismissible2({
    Key? key,
    required this.child,
    this.onDismissed,
    this.dismissThreshold = 0.2,
  }) : super(key: key);

  final Widget child;
  final double dismissThreshold;
  final VoidCallback? onDismissed;

  @override
  State<CustomDismissible2> createState() => _CustomDismissible2State();
}

class _CustomDismissible2State extends State<CustomDismissible2> with SingleTickerProviderStateMixin{

  late AnimationController _animateController;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Decoration> _opacityAnimation;
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _animateController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _updateMoveAnimation();
  }

  @override
  void dispose() {
    _animateController.dispose();
    super.dispose();
  }

  void _updateMoveAnimation() {
    final double end = _dragExtent.sign;

    _moveAnimation = _animateController.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: Offset(0, end),
      ),
    );

    _scaleAnimation = _animateController.drive(Tween<double>(
      begin: 1,
      end: 0.5,
    ));

    _opacityAnimation = DecorationTween(
      begin: BoxDecoration(
        color: const Color(0xFF000000),
      ),
      end: BoxDecoration(
        color: const Color(0x00000000),
      ),
    ).animate(_animateController);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBoxTransition(
      decoration: _opacityAnimation,
      child: SlideTransition(
        position: _moveAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
