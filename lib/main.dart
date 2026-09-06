import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const GhostMusicApp());
}

class GhostMusicApp extends StatelessWidget {
  const GhostMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0C0C10),
        brightness: Brightness.dark,
        fontFamily: 'sans-serif',
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();

  List<SongModel> _songs = [];
  int? _currentIndex;
  bool _isPlaying = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndFetchAudio();

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _requestPermissionAndFetchAudio() async {
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      await _audioQuery.permissionsRequest();
    }
    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    setState(() {
      _songs = songs.where((s) => s.isMusic == true).toList();
    });
  }

  Future<void> _playSong(int index) async {
    try {
      _currentIndex = index;
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_songs[index].uri!)));
      _player.play();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot play this file: $e')),
      );
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SongModel? currentSong = _currentIndex != null && _songs.isNotEmpty ? _songs[_currentIndex!] : null;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTab,
            children: [
              _buildHomeFeedTab(),
              _buildMyMusicTab(),
            ],
          ),

          // Floating Frosted Mini-Player
          if (currentSong != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: GestureDetector(
                onTap: () => _openNowPlaying(currentSong),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: const Color(0xFF1F1F28).withOpacity(0.85),
                      child: Row(
                        children: [
                          QueryArtworkWidget(
                            id: currentSong.id,
                            type: ArtworkType.AUDIO,
                            artworkBorder: BorderRadius.circular(12),
                            nullArtworkWidget: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Image(image: AssetImage('assets/logo.png'), width: 26),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  currentSong.artist ?? "Unknown Artist",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: const Color(0xFFD8F25C),
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Frosted Floating Bottom Navigation Bar
          Positioned(
            left: 36,
            right: 36,
            bottom: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: const Color(0xFF1E1E24).withOpacity(0.75),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navButton(Icons.home_filled, 0),
                      _navButton(Icons.library_music_rounded, 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD8F25C) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white60,
          size: 22,
        ),
      ),
    );
  }

  // Home Screen Layout matching UI Screen 1
  Widget _buildHomeFeedTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/logo.png', width: 38, height: 38),
              ),
              const Spacer(),
              _roundIcon(Icons.search),
              const SizedBox(width: 10),
              _roundIcon(Icons.favorite_border),
            ],
          ),
          const SizedBox(height: 18),
          const Text("Hi, Samantha", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryPill("All", true),
                _categoryPill("New Release", false),
                _categoryPill("Trending", false),
                _categoryPill("Top Playlists", false),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text("Curated & trending", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Purple Discover Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFC6A7FE),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Discover weekly", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 6),
                      const Text("Local offline tunes on your storage", style: TextStyle(color: Colors.black87, fontSize: 12)),
                      const SizedBox(height: 14),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF322353),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                          onPressed: () {
                            if (_songs.isNotEmpty) _playSong(0);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Image.asset('assets/logo.png', width: 85, height: 85),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Recent Tracks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._songs.take(5).map((song) => _buildTrackTile(song, _songs.indexOf(song))),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // My Music Screen matching UI Screen 3
  Widget _buildMyMusicTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _roundIcon(Icons.arrow_back, onTap: () => setState(() => _selectedTab = 0)),
                const Spacer(),
                const Text("My Music", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                _roundIcon(Icons.more_horiz),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                _categoryPill("All", true),
                _categoryPill("Playlists", false),
                _categoryPill("Liked Songs", false),
                _categoryPill("Downloaded", false),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _songs.isEmpty
                ? const Center(child: Text("No songs found. Grant storage permissions.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      return _buildTrackTile(_songs[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(SongModel song, int index) {
    bool isCurrentPlaying = _currentIndex == index;
    return ListTile(
      onTap: () => _playSong(index),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: Container(
              color: const Color(0xFF1E1E24),
              child: const Image(image: AssetImage('assets/logo.png'), width: 24),
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, color: isCurrentPlaying ? const Color(0xFFD8F25C) : Colors.white),
      ),
      subtitle: Text(
        song.artist ?? "Unknown",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(
          isCurrentPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_arrow_rounded,
          color: isCurrentPlaying ? const Color(0xFFD8F25C) : Colors.white60,
        ),
        onPressed: () {
          if (isCurrentPlaying) {
            _togglePlayPause();
          } else {
            _playSong(index);
          }
        },
      ),
    );
  }

  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E24),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _categoryPill(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD8F25C) : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white60,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Full Screen Circular Now Playing Layout matching UI Screen 2
  void _openNowPlaying(SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _player.duration ?? Duration.zero;

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F14),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("Now Playing", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.favorite_border, size: 22),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Circular Vinyl Album Art
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD8F25C).withOpacity(0.12),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 260,
                        artworkWidth: 260,
                        nullArtworkWidget: Container(
                          color: const Color(0xFF1E1E24),
                          child: const Center(
                            child: Image(image: AssetImage('assets/logo.png'), width: 110),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.artist ?? "Unknown Artist",
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  // Progress Bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFFD8F25C),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFFD8F25C),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                      onChanged: (val) {
                        _player.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        Text(_formatDuration(duration), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(Icons.shuffle, color: Colors.white54, size: 22),
                      IconButton(
                        icon: const Icon(Icon
