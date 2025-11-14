# Replace the archive_case function with this fixed version

@app.route('/api/cases/archive/<case_id>', methods=['POST'])
def archive_case(case_id):
    try:
        db = get_db()
        cursor = db.cursor()
        
        # Update case status to archived
        cursor.execute("UPDATE cases SET status = 'archived', closed_date = CURDATE() WHERE case_id = %s", (case_id,))
        
        # Move all evidence from hot to cold
        cursor.execute("UPDATE evidence_metadata SET blockchain_type = 'cold' WHERE case_id = %s", (case_id,))
        
        affected_rows = cursor.rowcount
        db.commit()
        cursor.close()
        db.close()
        
        return jsonify({
            'success': True, 
            'message': f'Case {case_id} archived to cold blockchain. {affected_rows} evidence items moved.'
        })
    except Exception as e:
        print(f"Archive error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
