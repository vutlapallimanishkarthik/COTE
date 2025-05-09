import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentShortsViewer extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const StudentShortsViewer({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<StudentShortsViewer> createState() => _StudentShortsViewerState();
}

class _StudentShortsViewerState extends State<StudentShortsViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _preloadedIndices = {};
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeControllerAtIndex(_currentIndex);
    _preloadAdjacentVideos(_currentIndex);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentIndex) {
      _controllers[_currentIndex]?.pause();
      setState(() {
        _currentIndex = newIndex;
        _showControls = false;
      });
      if (_controllers.containsKey(newIndex)) {
        _controllers[newIndex]?.play();
      } else {
        _initializeControllerAtIndex(newIndex);
      }
      _preloadAdjacentVideos(newIndex);
      _disposeDistantControllers(newIndex);
    }
  }

  void _preloadAdjacentVideos(int index) {
    for (int i = 1; i <= 2; i++) {
      final preloadIndex = index + i;
      if (preloadIndex < widget.videos.length && !_preloadedIndices.contains(preloadIndex)) {
        _preloadVideoAtIndex(preloadIndex);
      }
    }
  }

  void _preloadVideoAtIndex(int index) {
    if (index >= 0 && index < widget.videos.length && !_controllers.containsKey(index)) {
      _preloadedIndices.add(index);
      final videoUrl = widget.videos[index]['url'];
      final controller = VideoPlayerController.network(videoUrl, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      controller.setVolume(0);
      controller.initialize();
      _controllers[index] = controller;
    }
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    final videoUrl = widget.videos[index]['url'];
    if (_controllers.containsKey(index)) {
      final controller = _controllers[index]!;
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      controller.setLooping(true);
      controller.setVolume(1.0);
      controller.play();
      return;
    }
    final controller = VideoPlayerController.network(videoUrl, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controllers[index] = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(true);
      if (index == _currentIndex) {
        controller.play();
      }
      setState(() {});
    } catch (e) {
      print("Error initializing video $index: $e");
    }
  }

  void _disposeDistantControllers(int currentIndex) {
    const int keepRange = 3;
    final keysToRemove = _controllers.keys.where((idx) => (idx - currentIndex).abs() > keepRange).toList();
    for (final idx in keysToRemove) {
      _controllers[idx]?.dispose();
      _controllers.remove(idx);
      _preloadedIndices.remove(idx);
    }
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Shorts"),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) => _buildVideoPage(index),
      ),
    );
  }

  Widget _buildVideoPage(int index) {
    final video = widget.videos[index];
    final String videoTitle = video['title'] ?? 'Short #${index + 1}';
    final String videoDescription = video['description'] ?? '';
    final String teacherName = video['teacherName'] ?? 'Unknown';

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _controllers.containsKey(index) && _controllers[index]!.value.isInitialized
            ? Center(
                child: AspectRatio(
                  aspectRatio: _controllers[index]!.value.aspectRatio,
                  child: VideoPlayer(_controllers[index]!))
              )
            : const Center(child: CircularProgressIndicator(color: Colors.white)),

          if (_showControls)
            Center(
              child: IconButton(
                icon: Icon(
                  _controllers[index]?.value.isPlaying ?? false ? Icons.pause_circle : Icons.play_circle,
                  size: 64,
                  color: Colors.white,
                ),
                onPressed: _togglePlayPause,
              ),
            ),

          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(videoTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("by @$teacherName",
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text(videoDescription,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
