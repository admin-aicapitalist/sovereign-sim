#!/usr/bin/env python3
"""Summarize an exported run without loading the game or contacting a server."""
import argparse
from collections import Counter
import json
from pathlib import Path


def summarize(log):
    if log.get('format') != 1 or not isinstance(log.get('events'), list):
        raise ValueError('Expected a Sovereign format-1 run log')
    events = log['events']
    heroes, segments, timeline, samples = {}, [], [], []
    damage = Counter()
    palace_ids = set()
    counts = Counter()
    seen = set()
    for event in events:
        identity = (event['segment'], event['seq'])
        if identity in seen:
            raise ValueError(f'Duplicate event: {identity}')
        seen.add(identity)
        kind, data = event['event'], event['data']
        counts[kind] += 1
        stamp = {'segment': event['segment'], 'time': event['time']}
        checkpoint = data.get('checkpoint')
        if checkpoint:
            palace_ids.update(int(b['id']) for b in checkpoint['buildings'] if b['type'] == 'palace')
            for actor in checkpoint['units']:
                if actor['hero']:
                    heroes[int(actor['id'])] = {'id': actor['id'], 'name': actor['name'], 'type': actor['type']}
        if kind.startswith('run.'):
            timeline.append({**stamp, 'event': kind, 'result': data.get('result', '')})
            if checkpoint and kind != 'run.ended':
                segments.append({**stamp, 'origin': kind, 'wall_time_utc': data.get('wall_time_utc')})
        elif kind == 'actor.created' and data['hero']:
            heroes[int(data['id'])] = {'id': data['id'], 'name': data['name'], 'type': data['type']}
        elif kind == 'combat.damage':
            damage[str(int(data['target']))] += data['amount']
        elif kind == 'hero.journey':
            journey = data['journey']
            timeline.append({**stamp, 'event': kind, 'hero': data['id'], 'name': data['name'],
                             'aspect': journey['aspect'], 'stage': journey['stage'],
                             'shadow_count': journey['shadow_count'], 'reason': data['reason']})
        elif kind == 'story.event' and data['kind'] in ('death', 'theft', 'leisure', 'boss', 'lair'):
            timeline.append({**stamp, 'event': data['kind'], 'hero': data['hero'], 'detail': data['detail']})
        elif kind == 'notice':
            timeline.append({**stamp, 'event': 'notice', 'text': data['text']})
        elif kind == 'world.sample':
            # Keep one row per game minute per segment, plus the latest row.
            row = {**stamp, 'gold': data['gold'], 'living_actors': len(data['actors']),
                   'shadow_heroes': [a['id'] for a in data['actors'] if a['journey'].get('aspect') == 'shadow'],
                   'stats': data['stats']}
            if not samples or samples[-1]['segment'] != event['segment'] or int(samples[-1]['time'] / 60) != int(event['time'] / 60):
                samples.append(row)
            else:
                samples[-1] = row
    return {'run': log['run'], 'event_count': len(events), 'event_types': dict(counts), 'segments': segments,
            'heroes': list(heroes.values()), 'damage_to_heroes': {str(h): damage[str(h)] for h in heroes},
            'palace_damage': sum(damage[str(i)] for i in palace_ids), 'samples': samples, 'timeline': timeline,
            'note': 'Observed events only. Damage totals include every recorded segment, including replay after loading an older save. Shadow entries are cumulative within each restored journey; do not count repeated checkpoint values as new failures.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(summarize(json.loads(args.log.read_text())), indent=2))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'Cannot review run: {error}\n')
