import React, { useState, useEffect } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import Video from 'react-native-video';
import DeviceBinding from './src/DeviceBinding';
import BundleManager from './src/BundleManager';
import MediaPlayer from './src/MediaPlayer';

function App() {
  const [deviceInfo, setDeviceInfo] = useState(null);
  const [bundle, setBundle] = useState(null);
  const [mediaFiles, setMediaFiles] = useState([]);
  const [selectedMedia, setSelectedMedia] = useState(null);
  const [playbackStats, setPlaybackStats] = useState({});
  const [loading, setLoading] = useState(true);
  const [playing, setPlaying] = useState(false);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      // Initialize device binding
      const info = await DeviceBinding.initialize();
      setDeviceInfo(info);

      // Load current bundle if exists
      const currentBundle = await BundleManager.getCurrentBundle();
      if (currentBundle) {
        setBundle(currentBundle);
        const files = await BundleManager.getMediaFiles();
        setMediaFiles(files);
        
        // Load playback stats
        const stats = await MediaPlayer.getAllPlaybackStats();
        setPlaybackStats(stats);
      }
    } catch (error) {
      Alert.alert('Initialization Error', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handlePlayMedia = async (mediaId) => {
    try {
      setLoading(true);
      
      const result = await MediaPlayer.prepareMedia(mediaId);
      
      if (!result.canPlay) {
        Alert.alert(
          'Playback Limit Reached',
          result.reason,
          [{ text: 'OK' }]
        );
        return;
      }

      // Record playback start
      await MediaPlayer.startPlayback(mediaId);
      
      // Update selected media for video player
      setSelectedMedia({
        id: mediaId,
        path: result.mediaPath,
        info: result.mediaFile
      });
      setPlaying(true);

      // Refresh stats
      const stats = await MediaPlayer.getAllPlaybackStats();
      setPlaybackStats(stats);
      
    } catch (error) {
      Alert.alert('Playback Error', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleStopPlayback = async () => {
    setPlaying(false);
    setSelectedMedia(null);
    await MediaPlayer.cleanupPlayback();
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.centerContent}>
          <ActivityIndicator size="large" color="#007AFF" />
          <Text style={styles.loadingText}>Loading...</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!bundle) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.centerContent}>
          <Text style={styles.title}>No Bundle Loaded</Text>
          <Text style={styles.subtitle}>
            Please load a media bundle to continue
          </Text>
          {deviceInfo && (
            <View style={styles.deviceInfo}>
              <Text style={styles.infoLabel}>Device ID:</Text>
              <Text style={styles.infoValue}>{deviceInfo.deviceId}</Text>
            </View>
          )}
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" />
      <ScrollView style={styles.scrollView}>
        <View style={styles.header}>
          <Text style={styles.title}>Scripture Media Player</Text>
          <Text style={styles.subtitle}>Bundle: {bundle.bundleId}</Text>
        </View>

        {selectedMedia && playing ? (
          <View style={styles.playerContainer}>
            <Video
              source={{ uri: `file://${selectedMedia.path}` }}
              style={styles.videoPlayer}
              controls={true}
              resizeMode="contain"
              onEnd={handleStopPlayback}
              onError={(error) => {
                Alert.alert('Playback Error', error.error.errorString);
                handleStopPlayback();
              }}
            />
            <TouchableOpacity
              style={styles.stopButton}
              onPress={handleStopPlayback}
            >
              <Text style={styles.stopButtonText}>Stop</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <View style={styles.mediaList}>
            <Text style={styles.sectionTitle}>Media Files</Text>
            {mediaFiles.map((media) => {
              const stats = playbackStats[media.id] || {};
              return (
                <View key={media.id} style={styles.mediaCard}>
                  <Text style={styles.mediaTitle}>{media.title}</Text>
                  <Text style={styles.mediaType}>{media.type}</Text>
                  
                  {stats.playbackLimit && (
                    <View style={styles.statsContainer}>
                      <Text style={styles.statsText}>
                        Plays: {stats.totalPlays || 0} / {stats.playbackLimit.maxPlays}
                      </Text>
                      <Text style={styles.statsText}>
                        Remaining: {stats.remainingPlays || 0}
                      </Text>
                      {stats.nextResetTime && (
                        <Text style={styles.statsText}>
                          Reset: {new Date(stats.nextResetTime).toLocaleString()}
                        </Text>
                      )}
                    </View>
                  )}

                  <TouchableOpacity
                    style={[
                      styles.playButton,
                      !stats.canPlay && styles.playButtonDisabled
                    ]}
                    onPress={() => handlePlayMedia(media.id)}
                    disabled={!stats.canPlay}
                  >
                    <Text style={styles.playButtonText}>
                      {stats.canPlay ? 'Play' : 'Limit Reached'}
                    </Text>
                  </TouchableOpacity>
                </View>
              );
            })}
          </View>
        )}

        {deviceInfo && (
          <View style={styles.footer}>
            <Text style={styles.footerText}>Device: {deviceInfo.model}</Text>
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  scrollView: {
    flex: 1,
  },
  centerContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  header: {
    padding: 20,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333333',
  },
  subtitle: {
    fontSize: 14,
    color: '#666666',
    marginTop: 5,
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#666666',
  },
  deviceInfo: {
    marginTop: 20,
    padding: 15,
    backgroundColor: '#F0F0F0',
    borderRadius: 8,
    width: '100%',
  },
  infoLabel: {
    fontSize: 12,
    color: '#666666',
    marginBottom: 5,
  },
  infoValue: {
    fontSize: 14,
    fontFamily: 'monospace',
    color: '#333333',
  },
  playerContainer: {
    padding: 20,
  },
  videoPlayer: {
    width: '100%',
    height: 300,
    backgroundColor: '#000000',
  },
  stopButton: {
    marginTop: 15,
    backgroundColor: '#FF3B30',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
  },
  stopButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  mediaList: {
    padding: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 15,
  },
  mediaCard: {
    backgroundColor: '#FFFFFF',
    padding: 15,
    borderRadius: 8,
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  mediaTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 5,
  },
  mediaType: {
    fontSize: 12,
    color: '#999999',
    textTransform: 'uppercase',
    marginBottom: 10,
  },
  statsContainer: {
    marginBottom: 10,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  statsText: {
    fontSize: 12,
    color: '#666666',
    marginBottom: 3,
  },
  playButton: {
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 6,
    alignItems: 'center',
  },
  playButtonDisabled: {
    backgroundColor: '#CCCCCC',
  },
  playButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  footer: {
    padding: 20,
    alignItems: 'center',
  },
  footerText: {
    fontSize: 12,
    color: '#999999',
  },
});

export default App;
