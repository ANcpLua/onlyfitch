import { useState, useEffect, useCallback } from 'react'
import './App.css'

interface StreamInfo {
  name: string
  displayName: string
  isOnline: boolean
  viewerCount: number
  gameName: string
  title: string
  thumbnailUrl: string
}

interface Config {
  clientId: string
  accessToken: string
  channels: string[]
}

function App() {
  const [streams, setStreams] = useState<StreamInfo[]>([])
  const [config, setConfig] = useState<Config>({ clientId: '', accessToken: '', channels: [] })
  const [showSettings, setShowSettings] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null)

  const [clientId, setClientId] = useState('')
  const [accessToken, setAccessToken] = useState('')
  const [channelsText, setChannelsText] = useState('')

  const hasValidConfig = config.clientId && config.accessToken && config.channels.length > 0

  useEffect(() => {
    const saved = localStorage.getItem('twitchConfig')
    if (saved) {
      const parsed = JSON.parse(saved)
      setConfig(parsed)
      setClientId(parsed.clientId)
      setAccessToken(parsed.accessToken)
      setChannelsText(parsed.channels.join('\n'))
    }
  }, [])

  const fetchStreams = useCallback(async () => {
    if (!hasValidConfig) return

    setIsLoading(true)
    try {
      const params = new URLSearchParams()
      config.channels.forEach(ch => params.append('user_login', ch))

      const response = await fetch(`https://api.twitch.tv/helix/streams?${params}`, {
        headers: {
          'Client-ID': config.clientId,
          'Authorization': `Bearer ${config.accessToken}`
        }
      })

      if (!response.ok) throw new Error('API Error')

      const data = await response.json()
      const onlineStreams: StreamInfo[] = data.data.map((s: any) => ({
        name: s.user_login,
        displayName: s.user_name,
        isOnline: true,
        viewerCount: s.viewer_count,
        gameName: s.game_name || 'Just Chatting',
        title: s.title,
        thumbnailUrl: s.thumbnail_url.replace('{width}', '440').replace('{height}', '248')
      }))

      const onlineNames = new Set(onlineStreams.map(s => s.name.toLowerCase()))
      const offlineStreams: StreamInfo[] = config.channels
        .filter(ch => !onlineNames.has(ch.toLowerCase()))
        .map(ch => ({
          name: ch,
          displayName: ch,
          isOnline: false,
          viewerCount: 0,
          gameName: '',
          title: '',
          thumbnailUrl: ''
        }))

      setStreams([...onlineStreams.sort((a, b) => b.viewerCount - a.viewerCount), ...offlineStreams])
      setLastRefresh(new Date())
    } catch (err) {
      console.error('Failed to fetch streams:', err)
    } finally {
      setIsLoading(false)
    }
  }, [config, hasValidConfig])

  useEffect(() => {
    fetchStreams()
    const interval = setInterval(fetchStreams, 60000)
    return () => clearInterval(interval)
  }, [fetchStreams])

  const saveConfig = () => {
    const newConfig: Config = {
      clientId,
      accessToken,
      channels: channelsText.split('\n').map(s => s.trim()).filter(Boolean)
    }
    setConfig(newConfig)
    localStorage.setItem('twitchConfig', JSON.stringify(newConfig))
    setShowSettings(false)
  }

  const launchStream = async (channel: string) => {
    const url = `https://twitch.tv/${channel}`
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      await invoke('launch_stream', { channel })
    } catch {
      window.open(url, '_blank')
    }
  }

  const formatViewers = (count: number): string => {
    if (count >= 1000) return `${(count / 1000).toFixed(1)}K`
    return count.toString()
  }

  const liveStreams = streams.filter(s => s.isOnline)
  const offlineStreams = streams.filter(s => !s.isOnline)

  if (!hasValidConfig) {
    return (
      <div className="app">
        <div className="setup-prompt">
          <div className="setup-icon">📺</div>
          <h1>Welcome to OnlyFitch</h1>
          <p>Configure your Twitch API credentials to get started</p>
          <button className="glass-button primary" onClick={() => setShowSettings(true)}>
            Open Settings
          </button>
          <a href="https://dev.twitch.tv" target="_blank" rel="noopener" className="dev-link">
            Need API credentials? Visit dev.twitch.tv
          </a>
        </div>
        {showSettings && <SettingsModal {...{ clientId, setClientId, accessToken, setAccessToken, channelsText, setChannelsText, saveConfig, onClose: () => setShowSettings(false) }} />}
      </div>
    )
  }

  return (
    <div className="app">
      <header className="header glass">
        <h1>Streams</h1>
        <div className="header-actions">
          <button className="glass-button icon" onClick={fetchStreams} disabled={isLoading}>
            {isLoading ? '...' : '↻'}
          </button>
          {lastRefresh && (
            <span className="last-refresh">{lastRefresh.toLocaleTimeString()}</span>
          )}
          <button className="glass-button icon" onClick={() => setShowSettings(true)}>
            ⚙
          </button>
        </div>
      </header>

      <main className="content">
        {liveStreams.length > 0 && (
          <section className="section">
            <div className="section-header">
              <h2>Live Now</h2>
              <span className="count-badge">{liveStreams.length}</span>
            </div>
            <div className="stream-grid">
              {liveStreams.map(stream => (
                <StreamCard key={stream.name} stream={stream} onLaunch={launchStream} formatViewers={formatViewers} />
              ))}
            </div>
          </section>
        )}

        {offlineStreams.length > 0 && (
          <section className="section">
            <h2 className="offline-title">Offline</h2>
            <div className="offline-grid">
              {offlineStreams.map(stream => (
                <OfflineCard key={stream.name} stream={stream} onLaunch={launchStream} />
              ))}
            </div>
          </section>
        )}
      </main>

      {showSettings && <SettingsModal {...{ clientId, setClientId, accessToken, setAccessToken, channelsText, setChannelsText, saveConfig, onClose: () => setShowSettings(false) }} />}
    </div>
  )
}

function StreamCard({ stream, onLaunch, formatViewers }: { stream: StreamInfo, onLaunch: (ch: string) => void, formatViewers: (n: number) => string }) {
  const initial = stream.displayName.charAt(0).toUpperCase()
  const hue = stream.name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0) % 360

  return (
    <button className="stream-card glass" onClick={() => onLaunch(stream.name)}>
      <div className="thumbnail-container">
        <img src={stream.thumbnailUrl} alt={stream.title} className="thumbnail" loading="lazy" />
        <span className="live-badge">LIVE</span>
      </div>
      <div className="stream-info">
        <div className="avatar" style={{ background: `hsl(${hue}, 60%, 50%)` }}>
          {initial}
        </div>
        <div className="stream-details">
          <span className="display-name">{stream.displayName}</span>
          <span className="game-name">{stream.gameName}</span>
        </div>
        <div className="viewer-count">
          <span className="eye">👁</span>
          {formatViewers(stream.viewerCount)}
        </div>
      </div>
    </button>
  )
}

function OfflineCard({ stream, onLaunch }: { stream: StreamInfo, onLaunch: (ch: string) => void }) {
  const initial = stream.displayName.charAt(0).toUpperCase()
  const hue = stream.name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0) % 360

  return (
    <button className="offline-card glass" onClick={() => onLaunch(stream.name)}>
      <div className="offline-placeholder">📺</div>
      <div className="offline-info">
        <div className="avatar small" style={{ background: `hsl(${hue}, 60%, 50%)` }}>
          {initial}
        </div>
        <div className="offline-details">
          <span className="display-name">{stream.displayName}</span>
          <span className="status">Offline</span>
        </div>
      </div>
    </button>
  )
}

function SettingsModal({ clientId, setClientId, accessToken, setAccessToken, channelsText, setChannelsText, saveConfig, onClose }: any) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal glass" onClick={e => e.stopPropagation()}>
        <h2>Settings</h2>
        <label>
          Client ID
          <input type="text" value={clientId} onChange={e => setClientId(e.target.value)} placeholder="Your Twitch Client ID" />
        </label>
        <label>
          Access Token
          <input type="password" value={accessToken} onChange={e => setAccessToken(e.target.value)} placeholder="Your Twitch Access Token" />
        </label>
        <label>
          Channels (one per line)
          <textarea value={channelsText} onChange={e => setChannelsText(e.target.value)} placeholder={"shroud\npokimane\nxqc"} rows={6} />
        </label>
        <div className="modal-actions">
          <button className="glass-button" onClick={onClose}>Cancel</button>
          <button className="glass-button primary" onClick={saveConfig}>Save</button>
        </div>
      </div>
    </div>
  )
}

export default App
