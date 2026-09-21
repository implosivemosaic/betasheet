#!/usr/bin/env python3
"""Bundle the accepted final review; no network calls or old lookup inputs."""
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(__file__).resolve().parents[1] / 'priv/geo'
review = json.loads((source / 'final-review.json').read_text())
responses = json.loads((source / 'results.json').read_text())['entries']
gyms, places, fsas = [], [], {}
for entry in review['entries']:
    if entry['status'] == 'REJECT':
        continue
    selected = entry['selected_point']
    candidate = selected['candidate']
    licenses = responses[entry['id']]['variants'][0]['response']['licenses']
    annotations = {}
    if entry['evidence_source'] == 'saved_response':
        raw = responses[entry['id']]['variants'][0]['response']['results'][selected['candidate_index']]
        assert raw['geometry'] == selected['point']
        # Keep source-related annotation only, not unrelated proprietary enrichments.
        annotations = {k: v for k, v in raw.get('annotations', {}).items()
                       if k in ('OSM', 'source', 'sources', 'license', 'licence')}
    row = dict(selected['point'], provider='OpenCage', name=candidate['formatted'],
               formatted_address=candidate['formatted'], precision=entry['status'],
               result_type=candidate['result_type'], components=candidate['components'],
               confidence=candidate['confidence'], source_id=entry['id'],
               evidence_source=entry['evidence_source'], candidate_index=selected['candidate_index'],
               licenses=licenses, source_annotations=annotations,
               review_date=review['generated_at'], precision_note=entry['reason'])
    if entry['kind'] == 'gym':
        row['gym_id'] = int(entry['id'].split(':')[1])
        gyms.append(row)
    elif entry['kind'] == 'city':
        # Reviewed lookup alias; provider's independent display name is retained separately.
        row['name'] = entry['name']
        places.append(row)
    else:
        fsas[entry['name']] = row
assert (len(gyms), len(places), len(fsas)) == (54, 418, 524)
for filename, data in [('gyms', sorted(gyms, key=lambda r: r['gym_id'])),
                       ('ontario_places', sorted(places, key=lambda r: r['name'])),
                       ('ontario_fsa', dict(sorted(fsas.items())))]:
    (destination / (filename + '.json')).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
print('Bundled 54 gyms, 418 reviewed place aliases, 524 FSAs; 11 rejected entries excluded.')
