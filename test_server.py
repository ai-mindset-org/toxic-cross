import datetime as dt
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.parse
import shutil
import subprocess
import sys
from unittest.mock import patch
import server

class PrivateAPITest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.folder=Path(self.tmp.name)
        self.original=server.ИСТОЧНИКИ;server.ИСТОЧНИКИ=self.folder
        self.original_root=server.КОРЕНЬ;server.КОРЕНЬ=self.folder
        (self.folder/'workspace.html').write_text('<html><head></head><body>CURRENT WORKSPACE</body></html>')
        (self.folder/'index.html').write_text('<html><head></head><body>CURRENT WORKSPACE</body></html>')
        (self.folder/'classic.html').write_text('<html><head></head><body>CLASSIC CROSS</body></html>')
        self.http=server.Сервер(('127.0.0.1',0),server.Рук)
        self.thread=threading.Thread(target=self.http.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.http.shutdown();self.http.server_close();server.ИСТОЧНИКИ=self.original;server.КОРЕНЬ=self.original_root;self.tmp.cleanup()
    def post(self,path,body,origin=None):
        conn=http.client.HTTPConnection('127.0.0.1',self.http.server_address[1]);headers={'Content-Type':'application/json'}
        if origin:headers['Origin']=origin
        conn.request('POST',path,json.dumps(body),headers);response=conn.getresponse();status=response.status;response.read();conn.close();return status

    def request_json(self,path,body=None):
        conn=http.client.HTTPConnection('127.0.0.1',self.http.server_address[1])
        conn.request('GET' if body is None else 'POST',path,None if body is None else json.dumps(body),{} if body is None else {'Content-Type':'application/json'})
        response=conn.getresponse();status=response.status;data=json.loads(response.read());conn.close();return status,data

    def entry(self,**values):
        return {'occurrence':'a'*64,'start':'2026-10-16T09:00:00Z','end':'2026-10-16T10:00:00Z','recorded':'2026-10-16T11:00:00Z','feeling':-1,'energy':1,'reframe':'Fictional next step',**values}

    def test_sync_unions_native_and_web_preserves_newest_and_private_allowlist(self):
        self.assertEqual(self.request_json('/check-in',self.entry(title='DO NOT STORE'))[0],200)
        native=self.entry(occurrence='b'*64,recorded='2026-10-16T11:01:00.123Z',feeling=2)
        old=self.entry(recorded='2026-10-16T10:59:00Z',feeling=0)
        status,reply=self.request_json('/check-ins/sync',{'entries':[native,old]})
        self.assertEqual(status,200);self.assertEqual(len(reply['entries']),2)
        self.assertEqual(len(reply['revision']),64)
        self.assertEqual(next(x['feeling'] for x in reply['entries'] if x['occurrence']=='a'*64),-1)
        self.assertTrue(all(set(x)=={'occurrence','start','end','recorded','feeling','energy','reframe'} for x in reply['entries']))
        newer=self.entry(recorded='2026-10-16T12:02:00+01:00',feeling=1)
        status,reply=self.request_json('/check-ins/sync',{'entries':[newer]})
        self.assertEqual(status,200);self.assertEqual(next(x['feeling'] for x in reply['entries'] if x['occurrence']=='a'*64),1)
        self.assertEqual(self.request_json('/check-ins')[1],reply['entries'])

    def test_invalid_sync_batch_never_partially_writes(self):
        self.request_json('/check-in',self.entry())
        before=(self.folder/'check-ins.local.json').read_bytes()
        invalid=self.entry(occurrence='b'*64,feeling=True)
        self.assertEqual(self.post('/check-ins/sync',{'entries':[self.entry(feeling=2),invalid]}),400)
        self.assertEqual((self.folder/'check-ins.local.json').read_bytes(),before)
        self.assertEqual(self.post('/check-ins/sync',{'entries':[self.entry(start='2026-10-16T09:00:00')]}),400)
        future=(dt.datetime.now(dt.timezone.utc)+dt.timedelta(days=1)).isoformat()
        self.assertEqual(self.post('/check-ins/sync',{'entries':[self.entry(recorded=future)]}),400)
        self.assertEqual(self.post('/check-ins/sync',{'entries':[self.entry()]*5001}),400)
        self.assertEqual(self.post('/check-ins/sync',{'entries':[]},'https://untrusted.example'),403)

    def test_corrupt_journal_is_preserved_and_read_reports_failure(self):
        path=self.folder/'check-ins.local.json';path.write_text('{broken')
        self.assertEqual(self.request_json('/check-ins')[0],503)
        self.assertEqual(self.post('/check-ins/sync',{'entries':[self.entry()]}),400)
        self.assertEqual(path.read_text(),'{broken')

    def test_workspace_has_no_redirect_flash_and_classic_is_reachable(self):
        paths=['/','/index.html','/workspace.html','/движок/','/движок/index.html','/движок/workspace.html']
        for path in paths+['/classic-frame']:
            marker=b'CLASSIC CROSS' if path=='/classic-frame' else b'CURRENT WORKSPACE'
            for method in ['GET','HEAD']:
                with self.subTest(path=path,method=method):
                    conn=http.client.HTTPConnection('127.0.0.1',self.http.server_address[1]);conn.request(method,urllib.parse.quote(path)+'?from=menu')
                    r=conn.getresponse();text=r.read();self.assertEqual(r.status,200);self.assertIsNone(r.getheader('Location'))
                    if method=='GET': self.assertIn(marker,text)
                    self.assertNotIn(b'http-equiv="refresh"',text)
                    self.assertIn('no-store',r.getheader('Cache-Control'));conn.close()

    def test_source_kit_aliases_resolve_the_current_engine_and_explicit_archive(self):
        (self.folder/'workspace.html').unlink();(self.folder/'classic.html').unlink()
        engine=self.folder/'движок';engine.mkdir()
        (engine/'workspace.html').write_text('<html><head></head><body>SOURCE KIT WORKSPACE</body></html>')
        (engine/'index.html').write_text('<html><head></head><body>SOURCE KIT CLASSIC</body></html>')
        for path,marker in [('/index.html',b'SOURCE KIT WORKSPACE'),('/classic-frame',b'SOURCE KIT CLASSIC')]:
            conn=http.client.HTTPConnection('127.0.0.1',self.http.server_address[1]);conn.request('GET',path)
            r=conn.getresponse();text=r.read();self.assertEqual(r.status,200);self.assertIn(marker,text)
            self.assertIn(b'<base href="/%D0%B4%D0%B2%D0%B8%D0%B6%D0%BE%D0%BA/">',text);conn.close()

    def test_private_subdirectory_entrypoint_resolves_project_module(self):
        private=self.folder/'private';scripts=private/'сервер';scripts.mkdir(parents=True)
        shutil.copyfile(server.__file__,scripts/'статика.py')
        shutil.copyfile(Path(server.__file__).parent/'provenance.py',private/'provenance.py')
        shutil.copyfile(Path(server.__file__).parent/'board_state.py',private/'board_state.py')
        result=subprocess.run([sys.executable,'-c','import runpy,sys; runpy.run_path(sys.argv[1],run_name="private_layout")',str(scripts/'статика.py')],cwd=self.folder,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
    def test_private_checkin_validation_and_replace(self):
        body={'occurrence':'a'*64,'start':'2026-10-16T09:00:00Z','end':'2026-10-16T10:00:00Z','feeling':-1,'energy':1,'reframe':'A fictional next step','title':'MUST NOT BE STORED'}
        self.assertEqual(self.post('/check-in',body),200)
        self.assertEqual(self.post('/check-in',{**body,'feeling':2}),200)
        rows=json.loads((self.folder/'check-ins.local.json').read_text())['checkins'];self.assertEqual(len(rows),1)
        self.assertNotIn('title',rows[0]);self.assertEqual(rows[0]['feeling'],2)
        self.assertEqual(self.post('/check-in',{**body,'feeling':3}),400)
        self.assertEqual(self.post('/check-in',body,'https://untrusted.example'),403)
        self.assertEqual((self.folder/'check-ins.local.json').stat().st_mode&0o777,0o600)
    def test_checkins_change_the_journal_without_recollecting_or_reweighting_context(self):
        context=self.folder/'контекст.json';original=b'{"balance":"SOURCE WEIGHTS RETAINED"}\n';context.write_bytes(original)
        with patch.object(server.Рук,'refresh_calendar') as collect:
            self.assertEqual(self.request_json('/check-in',self.entry())[0],200)
            self.assertEqual(self.request_json('/check-ins/sync',{'entries':[self.entry(occurrence='c'*64)]})[0],200)
            collect.assert_not_called()
        self.assertEqual(context.read_bytes(),original)
        self.assertEqual(len(self.request_json('/check-ins')[1]),2)

    def test_calendar_allowlist_and_freshness(self):
        now=dt.datetime.now(dt.timezone.utc)
        body={'schemaVersion':1,'source':'krest-calendar-bridge','fetchedAt':now.isoformat(),'rangeStart':(now-dt.timedelta(days=1)).isoformat(),'rangeEnd':(now+dt.timedelta(days=1)).isoformat(),'events':[{'id':'b'*64,'title':'Fictional calendar','start':now.isoformat(),'end':(now+dt.timedelta(hours=1)).isoformat(),'allDay':False,'owner_response':'accepted','notes':'MUST NOT BE STORED'}]}
        with patch.object(server.Рук,'refresh_calendar'):
            self.assertEqual(self.post('/calendar-snapshot',body),200)
        stored=json.loads((self.folder/'calendar-control.json').read_text());self.assertNotIn('notes',stored['events'][0])
        self.assertEqual(self.post('/calendar-snapshot',{**body,'fetchedAt':(now-dt.timedelta(hours=2)).isoformat()}),400)

if __name__=='__main__':unittest.main()
