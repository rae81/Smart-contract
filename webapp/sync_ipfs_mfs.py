import mysql.connector
import subprocess

# Connect to database
db = mysql.connector.connect(
    host="localhost",
    port=3306,
    user="cocuser",
    password="cocpassword",
    database="coc_evidence"
)

cursor = db.cursor(dictionary=True)
cursor.execute("SELECT evidence_id, ipfs_hash FROM evidence_metadata")
evidence_list = cursor.fetchall()

print(f"Found {len(evidence_list)} evidence items to sync")

for evidence in evidence_list:
    ipfs_hash = evidence['ipfs_hash']
    evidence_id = evidence['evidence_id']
    mfs_path = f"/evidence/{evidence_id}"
    
    print(f"Syncing {evidence_id}: {ipfs_hash}")
    
    result = subprocess.run([
        'docker', 'exec', 'ipfs-node',
        'ipfs', 'files', 'cp',
        f'/ipfs/{ipfs_hash}',
        mfs_path
    ], capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"  ✓ Added to MFS: {mfs_path}")
    else:
        print(f"  ✗ Failed: {result.stderr}")

cursor.close()
db.close()

# List files in MFS
print("\n📁 Files in /evidence:")
result = subprocess.run([
    'docker', 'exec', 'ipfs-node',
    'ipfs', 'files', 'ls', '/evidence'
], capture_output=True, text=True)
print(result.stdout)
