from flask import Flask, request, jsonify
import requests
import sqlite3
from datetime import datetime
import threading
import time

from flask_cors import CORS

app = Flask(__name__)

# ⚠️ IMPORTANTE: Permitir todas as origens no Replit
CORS(app, resources={r"/*": {"origins": "*"}})

# Adicione também este header middleware
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

# Configuração dos webhooks (substitua pelos seus)
WEBHOOKS = {
    "NORMAL_WEBHOOK": "https://ptb.discord.com/api/webhooks/1455361732523327730/aCZn_oDnIDjOoHzCkrPk_x9ohfSFWSO9kNzkSFo0kYNxmZIyrOcrrqSN80S3tQs_LINk",
    "SPECIAL_WEBHOOK": "https://ptb.discord.com/api/webhooks/1455361536078905479/IptfKoKAO-imuZ39zysfeIBoHb-0ZIqOHkYHTc2AA7TqscwZA5xn8vKQmc4RbgJ5rZUP",
    "ULTRA_HIGH_WEBHOOK": "https://ptb.discord.com/api/webhooks/1455361629880582239/tpNHrWPlXGi8SyStifJ-A0mMYHLSIkP2kE_UzW6rZRRbS8xtLxmN1CvIk7081pbdo6eX",
    "BRAINROT_150M_WEBHOOK": "https://ptb.discord.com/api/webhooks/1455430968575000729/4GH6iNeP3K6EeCtmFja1KzYxqGSICaXxtJURaZVq9LWzSsT9SwKGVw2ZqVUzMAqhFQpf"
}

# Configuração do banco de dados
DB_FILE = "servers.db"

def init_db():
    """Inicializa o banco de dados"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS sent_servers
                 (job_id TEXT PRIMARY KEY,
                  timestamp DATETIME,
                  webhook_type TEXT,
                  category TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS sent_brainrot_150m
                 (job_id TEXT PRIMARY KEY,
                  timestamp DATETIME)''')
    conn.commit()
    conn.close()

def was_server_sent(job_id):
    """Verifica se o servidor já foi enviado"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT job_id FROM sent_servers WHERE job_id = ?", (job_id,))
    result = c.fetchone()
    conn.close()
    return result is not None

def was_brainrot_150m_sent(job_id):
    """Verifica se o alerta brainrot 150M já foi enviado"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT job_id FROM sent_brainrot_150m WHERE job_id = ?", (job_id,))
    result = c.fetchone()
    conn.close()
    return result is not None

def mark_server_sent(job_id, webhook_type, category):
    """Marca o servidor como enviado"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO sent_servers VALUES (?, ?, ?, ?)",
              (job_id, datetime.now(), webhook_type, category))
    conn.commit()
    conn.close()

def mark_brainrot_150m_sent(job_id):
    """Marca o alerta brainrot 150M como enviado"""
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO sent_brainrot_150m VALUES (?, ?)",
              (job_id, datetime.now()))
    conn.commit()
    conn.close()

def send_to_discord_webhook(embed_data, webhook_type):
    """Envia embed para o Discord"""
    if webhook_type not in WEBHOOKS:
        return False

    webhook_url = WEBHOOKS[webhook_type]

    # Construir embed no formato Discord
    embed_info = embed_data.get('embed_info', {})
    category_info = {
        "ULTRA_HIGH": {"color": 10181046, "emoji": "💎", "name": "ULTRA HIGH"},
        "SPECIAL": {"color": 16766720, "emoji": "🔥", "name": "ESPECIAL"},
        "NORMAL": {"color": 5793266, "emoji": "⭐", "name": "NORMAL"}
    }

    category = embed_data.get('category', 'NORMAL')
    info = category_info.get(category, category_info["NORMAL"])

    # DEBUG: Verificar o que está chegando
    print(f"🔍 DEBUG - embed_data['server_id']: {repr(embed_data.get('server_id'))}")
    print(f"🔍 DEBUG - embed_data['job_id']: {embed_data.get('job_id')}")

    # Usar o server_id formatado diretamente do embed_data
    server_id = embed_data.get('server_id')
    if not server_id:
        # Se não veio formatado, formatar agora
        job_id = embed_data.get('job_id', 'Unknown')
        server_id = f"``{job_id}``"

    # Garantir que está com backticps duplos
    if not server_id.startswith("```"):
        server_id = f"```{server_id}```"
    if not server_id.endswith("```"):
        server_id = f"{server_id}```"

    print(f"🔧 Server ID formatado para Discord: {repr(server_id)}")

    embed = {
        "title": f"{info['emoji']} {embed_info.get('highest_brainrot', {}).get('name', 'Unknown')}",
        "description": embed_info.get('description', ''),
        "color": info['color'],
        "fields": [
            {
                "name": "🌐 Informações do Servidor",
                "value": f"**Jogadores:** {embed_data['players']}/{embed_data['max_players']}\n"
                        f"**Server ID:** {server_id}\n"
                        f"**Total encontrados:** {embed_data['total_found']}",
                "inline": False
            }
        ],
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "footer": {
            "text": f"Scanner Automático • {info['name']}"
        }
    }

    payload = {
        "embeds": [embed]
    }

    # DEBUG: Verificar o payload antes de enviar
    print(f"📤 Payload sendo enviado para Discord:")
    print(f"   Server ID no payload: {repr(server_id)}")

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        if response.status_code < 400:
            print(f"✅ Enviado para Discord com sucesso!")
            print(f"🔤 Server ID enviado: {server_id}")
            return True
        else:
            print(f"❌ Erro Discord: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Erro ao enviar para Discord: {e}")
        return False

def check_brainrot_150m(embed_data):
    """Verifica se há brainrot > 150M e envia alerta"""
    job_id = embed_data['job_id']
    top_brainrots = embed_data.get('embed_info', {}).get('top_brainrots', [])

    if was_brainrot_150m_sent(job_id):
        return False

    has_high_brainrot = False
    highest_brainrot = None

    for brainrot in top_brainrots:
        if brainrot.get('numericGen', 0) >= 150000000:
            has_high_brainrot = True
            if not highest_brainrot or brainrot.get('numericGen', 0) > highest_brainrot.get('numericGen', 0):
                highest_brainrot = brainrot

    if not has_high_brainrot:
        return False

    # Construir embed para brainrot 150M
    description = "🚨 **Brainrot Highlight detectado!** 🚨\n\n"
    for i, brainrot in enumerate(top_brainrots, 1):
        if brainrot.get('numericGen', 0) >= 150000000:
            description += f"**{i}º** - {brainrot.get('name', 'Unknown')}: **{brainrot.get('valuePerSecond', '0/s')}**\n"

    embed = {
        "title": f"👑 {highest_brainrot.get('name', 'Unknown')}",
        "description": description,
        "color": 16711680,  # Vermelho
        "fields": [
            {
                "name": "👥 Jogadores no Servidor",
                "value": f"**{embed_data['players']}/{embed_data['max_players']}**",
                "inline": True
            },
            {
                "name": "📊 Maior Geração",
                "value": f"**{highest_brainrot.get('valuePerSecond', '0/s')}**",
                "inline": True
            }
        ],
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "footer": {
            "text": f"ALERTA BRAINROT 150M+ • Scanner Automático"
        }
    }

    payload = {
        "embeds": [embed]
    }

    try:
        response = requests.post(WEBHOOKS["BRAINROT_150M_WEBHOOK"], json=payload, timeout=10)
        if response.status_code < 400:
            mark_brainrot_150m_sent(job_id)
            print(f"🚨 Alerta brainrot 150M+ enviado: {job_id}")
            return True
    except Exception as e:
        print(f"Erro ao enviar alerta brainrot 150M: {e}")

    return False

@app.route('/webhook-filter', methods=['POST'])
def webhook_filter():
    """Endpoint principal para filtrar e encaminhar webhooks"""
    try:
        data = request.json

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        job_id = data.get('job_id')
        if not job_id:
            return jsonify({"status": "error", "message": "No job_id provided"}), 400

        # Log para debug
        server_id = data.get('server_id', 'Não fornecido')
        print(f"\n" + "="*50)
        print(f"📥 Recebido request do Roblox")
        print(f"📋 Job ID: {job_id}")
        print(f"🔤 Server ID recebido: {repr(server_id)}")
        print(f"📊 Dados completos recebidos:")
        for key, value in data.items():
            if key != 'embed_info':
                print(f"   {key}: {value}")

        # Verificar se o servidor já foi enviado
        if was_server_sent(job_id):
            print(f"📭 Servidor duplicado ignorado: {job_id}")
            return jsonify({"status": "duplicate", "message": "Server already sent"}), 200

        webhook_type = data.get('webhook_type')

        # Verificar brainrot 150M
        check_brainrot_150m(data)

        # Enviar para Discord
        if webhook_type and webhook_type in WEBHOOKS:
            success = send_to_discord_webhook(data, webhook_type)

            if success:
                # Marcar como enviado
                mark_server_sent(job_id, webhook_type, data.get('category', 'UNKNOWN'))
                print(f"✅ Embed enviado para Discord: {job_id}")
                return jsonify({"status": "sent", "message": "Embed sent to Discord"}), 200
            else:
                return jsonify({"status": "error", "message": "Failed to send to Discord"}), 500
        else:
            return jsonify({"status": "error", "message": "Invalid webhook type"}), 400

    except Exception as e:
        print(f"❌ Erro no servidor Python: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de verificação de saúde"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()}), 200

@app.route('/servers', methods=['GET'])
def list_servers():
    """Lista todos os servidores enviados"""
    try:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        c.execute("SELECT job_id, timestamp, webhook_type, category FROM sent_servers ORDER BY timestamp DESC")
        servers = c.fetchall()
        conn.close()

        server_list = []
        for server in servers:
            server_list.append({
                "job_id": server[0],
                "timestamp": server[1],
                "webhook_type": server[2],
                "category": server[3]
            })

        return jsonify({"status": "success", "servers": server_list, "count": len(server_list)}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

def cleanup_old_entries():
    """Limpa entradas antigas do banco de dados"""
    while True:
        try:
            conn = sqlite3.connect(DB_FILE)
            c = conn.cursor()
            # Remove entradas com mais de 24 horas
            c.execute("DELETE FROM sent_servers WHERE timestamp < datetime('now', '-24 hours')")
            c.execute("DELETE FROM sent_brainrot_150m WHERE timestamp < datetime('now', '-24 hours')")
            deleted = conn.total_changes
            conn.commit()
            conn.close()
            if deleted > 0:
                print(f"🧹 Banco de dados limpo: {deleted} entradas removidas")
        except Exception as e:
            print(f"Erro ao limpar banco: {e}")

        # Executa a cada hora
        time.sleep(3600)

@app.route('/')
def home():
    return jsonify({
        "status": "online",
        "service": "Brainrot Scanner API",
        "endpoints": {
            "health": "/health",
            "webhook_filter": "/webhook-filter (POST)",
            "servers_list": "/servers"
        },
        "timestamp": datetime.now().isoformat()
    })

if __name__ == '__main__':
    init_db()

    cleanup_thread = threading.Thread(target=cleanup_old_entries, daemon=True)
    cleanup_thread.start()

    app.run(host='0.0.0.0', port=5000, debug=True)
