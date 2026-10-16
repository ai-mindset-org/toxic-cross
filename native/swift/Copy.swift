import Foundation
enum Copy {
    static func name(_ raw:String)->String { ["обязательства":"Obligations","ресурсы":"Resources","будущее":"Future","прошлое":"Past","календарь":"Calendar","фокус":"Focus","обещания":"Promises","телеграм":"Telegram","волт":"Vault","техничка":"Infrastructure","звонки":"Calls","отклики":"Reflections","правки":"Edits","задачи":"Tasks","контур":"Context","переписка":"Messages","реестр обещаний":"Promise registry","борт":"Board","выдуманный день":"Fictional example","архив борта":"Board archive","наблюдение Mac":"Mac observation"][raw] ?? raw }
    static func status(_ raw:String)->String { ["live":"observed","quiet":"no activity reported","dead":"unavailable","stale":"stale","выключен":"disabled"][raw] ?? raw }
}
