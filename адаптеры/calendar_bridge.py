"""Optional read-only Calendar Control bridge, explicitly enabled in the native app."""
import datetime as dt
import json
from pathlib import Path

FILE = Path(__file__).parent.parent / 'источники/calendar-control.json'

def собрать(rules, now):
    try:
        data=json.loads(FILE.read_text())
        stamp=dt.datetime.fromisoformat(data['fetchedAt'].replace('Z','+00:00'))
        start=dt.datetime.fromisoformat(data['rangeStart'].replace('Z','+00:00'))
        end=dt.datetime.fromisoformat(data['rangeEnd'].replace('Z','+00:00'))
        day=now.replace(hour=0,minute=0,second=0,microsecond=0)
        if not -300<=(now-stamp).total_seconds()<=min(3600,data.get('maxAgeSeconds',3600)) or start>day or end<day+dt.timedelta(days=1):raise ValueError('stale or incomplete snapshot')
    except (OSError,ValueError,KeyError,TypeError):
        return {'статус':'dead','элементы':[],'события':[],'заметка':'Calendar bridge unavailable; free time unknown'}
    items=[];events=[];intervals=[];seen=set()
    for event in data['events']:
        a=dt.datetime.fromisoformat(event['start'].replace('Z','+00:00')).astimezone(now.tzinfo)
        b=dt.datetime.fromisoformat(event['end'].replace('Z','+00:00')).astimezone(now.tzinfo)
        if a.date()!=now.date() or event.get('allDay') or event.get('owner_response')=='declined' or b<=a or event['id'] in seen:continue
        seen.add(event['id']);weight=1.5 if b-a>dt.timedelta(minutes=90) else 1
        remaining=max(0,min(1,(b-now).total_seconds()/(b-a).total_seconds()))
        for arm,value in [('обязательства',weight*remaining),('прошлое',weight*(1-remaining))]:
            if value<=0:continue
            items.append({'id':event['id']+'-'+arm,'т':event['title'],'луч':arm,'вес':round(value,2),'источник':'календарь','охват':'ситуативное','т_ч':max(0,(a-now).total_seconds()/3600) if arm=='обязательства' else max(0,(now-b).total_seconds()/3600),'знак':'+' if arm=='прошлое' else '-','флип':'What is one useful next step?','факт':'Scheduled time; attendance and completion are unverified'})
        events.append({'id':event['id'],'reviewID':event['id'],'title':event['title'],'что':event['title'],'start':a.isoformat(),'end':b.isoformat(),'t':a.strftime('%H:%M'),'конец':b.strftime('%H:%M'),'луч':'обязательства','элементы':[event['id']+'-обязательства']})
        left=max(a,now,day+dt.timedelta(hours=9));right=min(b,day+dt.timedelta(hours=19))
        if right>left:intervals.append((left,right))
    merged=[]
    for a,b in sorted(intervals):
        if merged and a<=merged[-1][1]:merged[-1]=(merged[-1][0],max(b,merged[-1][1]))
        else:merged.append((a,b))
    busy=sum((b-a).total_seconds()/3600 for a,b in merged)
    available=max(0,(day+dt.timedelta(hours=19)-max(now,day+dt.timedelta(hours=9))).total_seconds()/3600-busy)
    items.append({'id':'calendar-free','т':f'{available:.1f} h unscheduled','луч':'ресурсы','вес':min(4,available*.5),'источник':'календарь','охват':'ситуативное','т_ч':12,'флип':'Choose one useful use of this time','факт':'Union of busy intervals in the remaining 09:00–19:00 window; availability is unverified'})
    return {'статус':'live','элементы':items,'события':events,'capturedAt':stamp.isoformat(),'expiresAt':(stamp+dt.timedelta(seconds=data.get('maxAgeSeconds',3600))).isoformat(),'заметка':f'{len(events)} timed events · Calendar Control · captured {data["fetchedAt"]}'}
