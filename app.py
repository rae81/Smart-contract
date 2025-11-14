
# Add blockchain info endpoint
@app.route('/api/blockchain/info')
def blockchain_info():
    try:
        # Get Hot Blockchain info
        hot_result = subprocess.run(
            ['docker', 'exec', 'cli', 'peer', 'channel', 'getinfo', '-c', 'hotchannel'],
            capture_output=True, text=True
        )
        
        # Get Cold Blockchain info
        cold_result = subprocess.run(
            ['docker', 'exec', 'cli-cold', 'peer', 'channel', 'getinfo', '-c', 'coldchannel'],
            capture_output=True, text=True
        )
        
        return jsonify({
            'hot': hot_result.stdout if hot_result.returncode == 0 else 'Not available',
            'cold': cold_result.stdout if cold_result.returncode == 0 else 'Not available'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Add container status endpoint
@app.route('/api/system/status')
def system_status():
    try:
        result = subprocess.run(
            ['docker', 'ps', '--format', '{{.Names}}\t{{.Status}}'],
            capture_output=True, text=True
        )
        containers = []
        for line in result.stdout.strip().split('\n'):
            if line:
                name, status = line.split('\t', 1)
                containers.append({'name': name, 'status': status})
        return jsonify(containers)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
