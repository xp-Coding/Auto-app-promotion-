import json
import time
import urllib.request

req = urllib.request.Request(
    'http://127.0.0.1:8765/api/video/generate',
    data=json.dumps({
        'brand_name': 'DevStudio',
        'archetype': 'saas_product_ad',
        'aspect_ratio': '16:9',
        'resolution': '720p',
        'description': 'AI developer companion that builds software fast',
        'features': ['Auto testing', 'Fast compile', 'Clean code'],
        'target_scenes': 3,
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'},
)
res = urllib.request.urlopen(req)
gen_data = json.loads(res.read().decode('utf-8'))
job_id = gen_data['job_id']
print('Job registered:', job_id)

for _ in range(30):
    time.sleep(2)
    poll_req = urllib.request.Request(f'http://127.0.0.1:8765/api/jobs/{job_id}')
    poll_data = json.loads(urllib.request.urlopen(poll_req).read().decode('utf-8'))
    print(f"Status: {poll_data['status']} | Stage: {poll_data['stage']} ({poll_data['progress']*100:.0f}%) | {poll_data['stage_message']}")
    if poll_data['status'] in ['completed', 'failed']:
        print("Final MP4:", poll_data.get('mp4_path'))
        print("Validation report:", json.dumps(poll_data.get('validation'), indent=2))
        assert poll_data['status'] == 'completed', f"Job failed: {poll_data.get('error')}"
        assert poll_data.get('validation', {}).get('is_valid') is True, "Validation is_valid must be True"
        print("SUCCESS: End-to-end video pipeline verified!")
        break
