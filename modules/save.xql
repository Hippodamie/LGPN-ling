xquery version "3.0";

declare namespace TEI = "http://www.tei-c.org/ns/1.0";
import module namespace config="http://www.existsolutions.com/apps/lgpn/config" at "config.xqm";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";


let $user := "#" || request:get-attribute("org.exist.lgpn-ling.user")
let $c := console:log(' save.xql ' || $user)
let $date := substring-before(xs:string(current-dateTime()), "T")
let $change := <change xmlns="http://www.tei-c.org/ns/1.0" when="{$date}" resp="{$user}">Edit entry via LGPN-ling interface</change>
let $data := request:get-data()
let $name := normalize-unicode($data//TEI:orth[@type ="latin"], 'NFD')
let $log := util:log("INFO", "data: " || count($data))
let $doc := doc(xmldb:store($config:names-root, concat($name , ".xml"), $data))
return 
    update insert $change into $doc//TEI:listChange
(:                    update replace $doc//TEI:orth[@type ="latin"] with $name):)