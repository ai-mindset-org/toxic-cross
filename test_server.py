import datetime as dt
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
import server

class PrivateAPITest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.folder=Path(self.tmp.name)
        self.original=server.ИСТОЧНИКИ;server.ИСТОЧНИКИ=self.folder
        self.http=server.Сервер(('127.0.0.1',0),server.Рук)
        self.thread=threading.Thread(target=self.http.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.http.shutdown();self.http.server_close();server.ИСТОЧНИКИ=self.original;self.tmp.cleanup()
    def post(self,path,body,origin=None):
        conn=http.client.HTTPConnection('127.0.0.1',self.http.server_address[1]);headers={'Content-Type':'application/json'}
        if origin:headers['Origin']=origin
        conn.request('POST',path,json.dumps(body),headers);response=conn.getresponse();status=response.status;response.read();conn.close();return status
    def test_private_checkin_validation_and_replace(self):
        body={'occurrence':'a'*64,'start':'2026-10-16T09:00:00Z','end':'2026-10-16T10:00:00Z','feeling':-1,'energy':1,'reframe':'A fictional next step','title':'MUST NOT BE STORED'}
        self.assertEqual(self.post('/check-in',body),200)
        self.assertEqual(self.post('/check-in',{**body,'feeling':2}),200)
        rows=json.loads((self.folder/'check-ins.local.json').read_text())['checkins'];self.assertEqual(len(rows),1)
        self.assertNotIn('title',rows[0]);self.assertEqual(rows[0]['feeling'],2)
        self.assertEqual(self.post('/check-in',{**body,'feeling':3}),400)
        self.assertEqual(self.post('/check-in',body,'https://untrusted.example'),403)
        self.assertEqual((self.folder/'check-ins.local.json').stat().st_mode&0o777,0o600)
    def test_calendar_allowlist_and_freshness(self):
        now=dt.datetime.now(dt.timezone.utc)
        body={'schemaVersion':1,'source':'krest-calendar-bridge','fetchedAt':now.isoformat(),'rangeStart':(now-dt.timedelta(days=1)).isoformat(),'rangeEnd':(now+dt.timedelta(days=1)).isoformat(),'events':[{'id':'b'*64,'title':'Fictional calendar','start':now.isoformat(),'end':(now+dt.timedelta(hours=1)).isoformat(),'allDay':False,'owner_response':'accepted','notes':'MUST NOT BE STORED'}]}
        with patch.object(server.Рук,'refresh_calendar'):
            self.assertEqual(self.post('/calendar-snapshot',body),200)
        stored=json.loads((self.folder/'calendar-control.json').read_text());self.assertNotIn('notes',stored['events'][0])
        self.assertEqual(self.post('/calendar-snapshot',{**body,'fetchedAt':(now-dt.timedelta(hours=2)).isoformat()}),400)

if __name__=='__main__':unittest.main()
