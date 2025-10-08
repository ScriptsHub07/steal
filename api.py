# api.py - Servidor Python
from flask import Flask, jsonify
import requests
import time
import threading

app = Flask(__name__)

class ServerCache:
    def __init__(self):
        self.data = []
        self.last_update = 0
        self.cache_duration = 30  # 30 segundos

cache = ServerCache()

def fetch_servers(place_id):
    try:
        servers = []
        cursor = ""
        max_servers = 50
        
        while len(servers) < max_servers:
            url = f"https://games.roblox.com/v1/games/{place_id}/servers/Public?sortOrder=Asc&limit=100"
            if cursor:
                url += f"&cursor={cursor}"
            
            response = requests.get(url)
            data = response.json()
            
            if not data.get('data'):
                break
                
            for server in data['data']:
                if len(servers) >= max_servers:
                    break
                if server['maxPlayers'] > server['playing'] and server['id']:
                    servers.append({
                        'id': server['id'],
                        'playing': server['playing'],
                        'maxPlayers': server['maxPlayers']
                    })
            
            cursor = data.get('nextPageCursor', '')
            if not cursor:
                break
                
        return servers
    except Exception as e:
        print(f"Erro: {e}")
        return []

@app.route('/servers/<place_id>')
def get_servers(place_id):
    # Verificar cache
    if time.time() - cache.last_update < cache.cache_duration and cache.data:
        return jsonify({
            'success': True,
            'servers': cache.data,
            'cached': True,
            'timestamp': time.time()
        })
    
    servers = fetch_servers(place_id)
    cache.data = servers
    cache.last_update = time.time()
    
    return jsonify({
        'success': True,
        'servers': servers,
        'cached': False,
        'timestamp': time.time()
    })

@app.route('/health')
def health():
    return jsonify({'status': 'online'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000)
