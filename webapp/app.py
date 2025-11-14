from flask import Flask, render_template, request, jsonify, send_file
import subprocess
import json
import requests
import mysql.connector
import hashlib
import os
from datetime import datetime
import time

app = Flask(__name__)

# MySQL connection
def get_db():
    try:
        return mysql.connector.connect(
            host="localhost",
            port=3306,
            user="cocuser",
            password="cocpassword",
            database="coc_evidence"
        )
    except Exception as e:
        print(f"Database connection error: {e}")
        raise

# Initialize IPFS MFS evidence directory
def init_ipfs_mfs():
    """Create /evidence directory in IPFS MFS if it doesn't exist"""
    try:
        # Use docker exec to ensure it works
        result = subprocess.run([
            'docker', 'exec', 'ipfs-node',
            'ipfs', 'files', 'stat', '/evidence'
        ], capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            print("✓ IPFS /evidence directory exists")
            return True
    except:
        pass
    
    # Create directory if it doesn't exist
    try:
        result = subprocess.run([
            'docker', 'exec', 'ipfs-node',
            'ipfs', 'files', 'mkdir', '-p', '/evidence'
        ], capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            print("✓ Created IPFS /evidence directory")
            return True
        else:
            print(f"⚠️ Could not create directory: {result.stderr}")
            return False
    except Exception as e:
        print(f"⚠️ Exception creating directory: {e}")
        return False

@app.route('/')
def index():
    # Initialize IPFS MFS on first request
    init_ipfs_mfs()
    return render_template('index.html')

@app.route('/api/evidence')
def get_evidence():
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM evidence_metadata ORDER BY collected_timestamp DESC")
        evidence = cursor.fetchall()
        
        for e in evidence:
            if e.get('collected_timestamp'):
                e['collected_timestamp'] = str(e['collected_timestamp'])
            if e.get('created_at'):
                e['created_at'] = str(e['created_at'])
            if e.get('updated_at'):
                e['updated_at'] = str(e['updated_at'])
        
        cursor.close()
        db.close()
        return jsonify(evidence)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/upload', methods=['POST'])
def upload_evidence():
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
            
        case_id = request.form.get('case_id')
        evidence_type = request.form.get('evidence_type')
        collected_by = request.form.get('collected_by')
        location = request.form.get('location')
        description = request.form.get('description', '')
        
        if not all([case_id, evidence_type, collected_by, location]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Generate evidence ID
        evidence_id = f"EVIDENCE-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        print(f"\n{'='*60}")
        print(f"📤 UPLOADING EVIDENCE: {evidence_id}")
        print(f"   File: {file.filename}")
        print(f"{'='*60}\n")
        
        # Save file temporarily
        temp_path = f"/tmp/{file.filename}"
        file.save(temp_path)
        
        # Calculate file size and hash
        file_size = os.path.getsize(temp_path)
        
        sha256 = hashlib.sha256()
        with open(temp_path, 'rb') as f:
            while chunk := f.read(8192):
                sha256.update(chunk)
        file_hash = sha256.hexdigest()
        
        # Upload to IPFS
        try:
            print(f"🔄 Uploading to IPFS...")
            with open(temp_path, 'rb') as f:
                ipfs_response = requests.post(
                    'http://localhost:5001/api/v0/add',
                    files={'file': f},
                    timeout=30
                )
            ipfs_data = ipfs_response.json()
            ipfs_hash = ipfs_data['Hash']
            
            print(f"✓ Uploaded to IPFS: {ipfs_hash}")
            
            # 🎯 CRITICAL: Add to IPFS MFS using docker exec
            # This is the part that makes files appear in WebUI
            safe_filename = "".join(c for c in file.filename if c.isalnum() or c in ('-', '_', '.'))
            mfs_path = f"/evidence/{evidence_id}_{safe_filename}"
            
            print(f"🔄 Adding to IPFS MFS at: {mfs_path}")
            
            # Method 1: Try docker exec (most reliable)
            result = subprocess.run([
                'docker', 'exec', 'ipfs-node',
                'ipfs', 'files', 'cp',
                f'/ipfs/{ipfs_hash}',
                mfs_path
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                print(f"✅ Successfully added to IPFS MFS: {mfs_path}")
                mfs_success = True
                
                # Wait a moment for MFS to update
                time.sleep(1)
                
                # Verify it was added
                verify_result = subprocess.run([
                    'docker', 'exec', 'ipfs-node',
                    'ipfs', 'files', 'ls', '/evidence'
                ], capture_output=True, text=True)
                
                print(f"📁 Files in /evidence: {verify_result.stdout}")
            else:
                print(f"❌ MFS add failed: {result.stderr}")
                print(f"   Return code: {result.returncode}")
                print(f"   Stdout: {result.stdout}")
                mfs_success = False
                
                # Try alternative method
                print("🔄 Trying alternative MFS add method...")
                alt_result = subprocess.run([
                    'docker', 'exec', 'ipfs-node', 'sh', '-c',
                    f'ipfs files cp /ipfs/{ipfs_hash} {mfs_path}'
                ], capture_output=True, text=True, timeout=10)
                
                if alt_result.returncode == 0:
                    print(f"✅ Alternative method succeeded!")
                    mfs_success = True
                else:
                    print(f"❌ Alternative method also failed: {alt_result.stderr}")
            
        except Exception as e:
            os.remove(temp_path)
            print(f"❌ IPFS upload failed: {e}")
            return jsonify({'error': f'IPFS upload failed: {str(e)}'}), 500
        
        # Store in database
        print(f"🔄 Saving to database...")
        db = get_db()
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO evidence_metadata 
            (evidence_id, case_id, evidence_type, file_size, ipfs_hash, sha256_hash, 
             collected_timestamp, collected_by, location, description, blockchain_type)
            VALUES (%s, %s, %s, %s, %s, %s, NOW(), %s, %s, %s, 'hot')
        """, (evidence_id, case_id, evidence_type, file_size, ipfs_hash, file_hash, 
              collected_by, location, description))
        db.commit()
        cursor.close()
        db.close()
        
        print(f"✓ Saved to database")
        
        # Clean up temp file
        os.remove(temp_path)
        
        print(f"\n{'='*60}")
        print(f"✅ UPLOAD COMPLETE")
        print(f"   Evidence ID: {evidence_id}")
        print(f"   IPFS Hash: {ipfs_hash}")
        print(f"   MFS Path: {mfs_path if mfs_success else 'Failed'}")
        print(f"   WebUI URL: https://webui.ipfs.io/#/files{mfs_path if mfs_success else ''}")
        print(f"{'='*60}\n")
        
        return jsonify({
            'success': True,
            'evidence_id': evidence_id,
            'ipfs_hash': ipfs_hash,
            'sha256': file_hash,
            'file_size': file_size,
            'mfs_path': mfs_path if mfs_success else None,
            'mfs_success': mfs_success,
            'webui_files_url': f'https://webui.ipfs.io/#/files{mfs_path}' if mfs_success else None
        })
    except Exception as e:
        print(f"❌ Upload error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/download/<ipfs_hash>')
def download_evidence(ipfs_hash):
    try:
        response = requests.get(f'http://localhost:8080/ipfs/{ipfs_hash}', timeout=30)
        if response.status_code == 200:
            temp_path = f"/tmp/download_{ipfs_hash}"
            with open(temp_path, 'wb') as f:
                f.write(response.content)
            return send_file(temp_path, as_attachment=True, download_name=f"evidence_{ipfs_hash}")
        else:
            return jsonify({'error': 'File not found in IPFS'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases')
def get_cases():
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM cases ORDER BY opened_date DESC")
        cases = cursor.fetchall()
        
        for c in cases:
            if c.get('opened_date'):
                c['opened_date'] = str(c['opened_date'])
            if c.get('closed_date'):
                c['closed_date'] = str(c['closed_date'])
            if c.get('created_at'):
                c['created_at'] = str(c['created_at'])
            if c.get('updated_at'):
                c['updated_at'] = str(c['updated_at'])
        
        cursor.close()
        db.close()
        return jsonify(cases)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases/ids')
def get_case_ids():
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT case_id, case_name, status FROM cases ORDER BY opened_date DESC")
        cases = cursor.fetchall()
        cursor.close()
        db.close()
        return jsonify(cases)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases/create', methods=['POST'])
def create_case():
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        case_name = data.get('case_name')
        case_number = data.get('case_number')
        case_type = data.get('case_type', 'General Investigation')
        investigating_agency = data.get('investigating_agency')
        lead_investigator = data.get('lead_investigator')
        description = data.get('description', '')
        
        if not all([case_name, case_number, investigating_agency, lead_investigator]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        case_id = f"CASE-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        db = get_db()
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO cases 
            (case_id, case_name, case_number, case_type, investigating_agency, 
             lead_investigator, status, opened_date, description)
            VALUES (%s, %s, %s, %s, %s, %s, 'open', CURDATE(), %s)
        """, (case_id, case_name, case_number, case_type, investigating_agency, 
              lead_investigator, description))
        db.commit()
        cursor.close()
        db.close()
        
        return jsonify({
            'success': True,
            'case_id': case_id,
            'case_name': case_name
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases/archive/<case_id>', methods=['POST'])
def archive_case(case_id):
    try:
        db = get_db()
        cursor = db.cursor()
        
        cursor.execute("UPDATE cases SET status = 'archived', closed_date = CURDATE() WHERE case_id = %s", (case_id,))
        cursor.execute("UPDATE evidence_metadata SET blockchain_type = 'cold' WHERE case_id = %s", (case_id,))
        
        affected_rows = cursor.rowcount
        db.commit()
        cursor.close()
        db.close()
        
        return jsonify({
            'success': True, 
            'message': f'Case {case_id} archived. {affected_rows} evidence items moved to cold blockchain.'
        })
    except Exception as e:
        print(f"Archive error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/cases/delete/<case_id>', methods=['DELETE'])
def delete_case(case_id):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("DELETE FROM cases WHERE case_id = %s", (case_id,))
        db.commit()
        rows_affected = cursor.rowcount
        cursor.close()
        db.close()
        
        if rows_affected > 0:
            return jsonify({'success': True, 'message': f'Case {case_id} deleted'})
        else:
            return jsonify({'error': 'Case not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases/close/<case_id>', methods=['POST'])
def close_case(case_id):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("UPDATE cases SET status = 'closed', closed_date = CURDATE() WHERE case_id = %s", (case_id,))
        db.commit()
        cursor.close()
        db.close()
        return jsonify({'success': True, 'message': f'Case {case_id} closed'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cases/reopen/<case_id>', methods=['POST'])
def reopen_case(case_id):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("UPDATE cases SET status = 'open', closed_date = NULL WHERE case_id = %s", (case_id,))
        db.commit()
        cursor.close()
        db.close()
        return jsonify({'success': True, 'message': f'Case {case_id} reopened'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blockchain/info')
def blockchain_info():
    try:
        hot_result = subprocess.run(
            ['docker', 'exec', 'cli', 'peer', 'channel', 'list'],
            capture_output=True, text=True, timeout=5
        )
        
        cold_result = subprocess.run(
            ['docker', 'exec', 'cli-cold', 'peer', 'channel', 'list'],
            capture_output=True, text=True, timeout=5
        )
        
        return jsonify({
            'hot': hot_result.stdout if hot_result.returncode == 0 else 'Not available',
            'cold': cold_result.stdout if cold_result.returncode == 0 else 'Not available',
            'hot_status': 'Running' if hot_result.returncode == 0 else 'Error',
            'cold_status': 'Running' if cold_result.returncode == 0 else 'Error'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blockchain/details')
def blockchain_details():
    try:
        # Hot blockchain info
        hot_channel = subprocess.run(
            ['docker', 'exec', 'cli', 'peer', 'channel', 'getinfo', '-c', 'hotchannel'],
            capture_output=True, text=True, timeout=10
        )
        
        # Cold blockchain info
        cold_channel = subprocess.run(
            ['docker', 'exec', 'cli-cold', 'peer', 'channel', 'getinfo', '-c', 'coldchannel'],
            capture_output=True, text=True, timeout=10
        )
        
        # IPFS info
        ipfs_status = 'Error'
        ipfs_data = {}
        
        try:
            ipfs_response = requests.post('http://localhost:5001/api/v0/version', timeout=5)
            if ipfs_response.status_code == 200:
                ipfs_data = ipfs_response.json()
                ipfs_status = 'Running'
        except:
            pass
        
        # MySQL stats
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("SELECT COUNT(*) as count FROM evidence_metadata")
        evidence_count = cursor.fetchone()['count']
        
        cursor.execute("SELECT COUNT(*) as count FROM cases")
        cases_count = cursor.fetchone()['count']
        
        cursor.execute("SELECT COUNT(*) as count FROM custody_events")
        custody_count = cursor.fetchone()['count']
        
        cursor.execute("SELECT SUM(file_size) as total FROM evidence_metadata")
        total_storage = cursor.fetchone()['total'] or 0
        
        cursor.close()
        db.close()
        
        return jsonify({
            'hot_blockchain': {
                'status': 'Running' if hot_channel.returncode == 0 else 'Error',
                'info': hot_channel.stdout if hot_channel.returncode == 0 else hot_channel.stderr
            },
            'cold_blockchain': {
                'status': 'Running' if cold_channel.returncode == 0 else 'Error',
                'info': cold_channel.stdout if cold_channel.returncode == 0 else cold_channel.stderr
            },
            'ipfs': {
                'status': ipfs_status,
                'stats': ipfs_data,
                'webui_url': 'https://webui.ipfs.io/#/files'
            },
            'mysql': {
                'status': 'Running',
                'evidence_count': evidence_count,
                'cases_count': cases_count,
                'custody_events': custody_count,
                'total_storage': total_storage
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/system/status')
def system_status():
    try:
        result = subprocess.run(
            ['docker', 'ps', '--format', '{{.Names}}\t{{.Status}}'],
            capture_output=True, text=True, timeout=5
        )
        containers = []
        for line in result.stdout.strip().split('\n'):
            if line and '\t' in line:
                name, status = line.split('\t', 1)
                containers.append({'name': name, 'status': status})
        return jsonify(containers)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Add endpoint to sync existing evidence to MFS
@app.route('/api/ipfs/sync-to-mfs', methods=['POST'])
def sync_to_mfs():
    """Sync all existing evidence to IPFS MFS"""
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT evidence_id, ipfs_hash FROM evidence_metadata")
        evidence_list = cursor.fetchall()
        cursor.close()
        db.close()
        
        synced = 0
        failed = 0
        
        for evidence in evidence_list:
            try:
                mfs_path = f"/evidence/{evidence['evidence_id']}"
                result = subprocess.run([
                    'docker', 'exec', 'ipfs-node',
                    'ipfs', 'files', 'cp',
                    f'/ipfs/{evidence["ipfs_hash"]}',
                    mfs_path
                ], capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    synced += 1
                else:
                    failed += 1
            except:
                failed += 1
        
        return jsonify({
            'success': True,
            'synced': synced,
            'failed': failed,
            'message': f'Synced {synced} files to MFS'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("=" * 60)
    print("🔐 Blockchain Chain of Custody Web Dashboard")
    print("=" * 60)
    print("📊 Access the dashboard at: http://localhost:5000")
    print("🗄️  Database: MySQL on localhost:3306")
    print("📦 IPFS API: http://localhost:5001")
    print("🌐 IPFS Gateway: http://localhost:8080")
    print("🌐 IPFS WebUI: https://webui.ipfs.io")
    print("=" * 60)
    
    # Initialize IPFS MFS on startup
    init_ipfs_mfs()
    
    app.run(host='0.0.0.0', port=5000, debug=True)
