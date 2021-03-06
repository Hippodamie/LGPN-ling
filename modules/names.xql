xquery version "3.0";

module namespace names="http://www.existsolutions.com/apps/lgpn/names";

declare namespace TEI = "http://www.tei-c.org/ns/1.0";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.existsolutions.com/apps/lgpn/config" at "config.xqm";
import module namespace i18n="http://exist-db.org/xquery/i18n/templates" at "i18n-templates.xql"; 
import module namespace functx = "http://www.functx.com";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";

declare
function names:delete-name($node as node(), $model as map(*), $delete as xs:string?) {
    if($delete) then 
        <div class="row">
            <div class="alert alert-danger col-sm-6">
                <strong>{names:delete-entry($delete)}</strong>!
            </div>
        </div>
    else ()
};


declare
function names:delete-entry($id as xs:string?) {
    let $entry := collection($config:names-root)//TEI:entry/id($id)[1]
    let $del := if($entry) then xmldb:remove(util:collection-name($entry), util:document-name($entry)) else ('fail')
    return if($del='fail') then ('Failed to delete ', <strong>{$id}</strong>) else (<strong>{$id}</strong>, ' deleted')
};

declare function names:entries($node as node(), $model as map(*)) {
    let $entries :=
    for $i in collection($config:names-root)//TEI:gramGrp
    order by $i/parent::TEI:entry//TEI:orth[@type='greek'][1]
        return $i
    
    return
    map { "entries" := $entries }
};

declare
 %templates:wrap
function names:entry-id($entry as node()) {
    data($entry/parent::TEI:entry/@xml:id)
};

declare
function names:entry-updated($entry as node()) {
    let $updated := if($entry) then xmldb:last-modified(util:collection-name($entry), util:document-name($entry)) else ()
    return <span>{substring-before($updated, 'T')}<span class="invisible">{$updated}</span></span>
(:    return max($entry/ancestor::TEI:TEI//TEI:change/@when/string()):)
};

declare
function names:entry-form($entry as node(), $langId as xs:string) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)
    let $bold := if ($langId='greek') then 'font-weight: bold;' else ()
    let $first :=  if ($pos) then 'dimmed' else () 

    let $content := data($entry/parent::TEI:entry//TEI:orth[@type=$langId][1])
    let $variant := if($langId='variant') 
        then 
            <span class="invisible">{replace($entry/parent::TEI:entry//TEI:orth[@type='variant'][1], "(\(\w*\))", "")}</span> 
        else 
            ()

    return 
        <span>
            {attribute style {$bold}}
            {attribute class {$first}}
            {$content}
        </span>
};

(:declare:)
(:function names:entry-stripped($entry as node(), $lang as xs:string) {:)
(:    replace(normalize-unicode($entry/parent::TEI:entry//TEI:orth[@type=$lang]/string(), 'NFD'), '[\p{M}\p{Sk}]', ''):)
(:};:)

declare
function names:entry-dialect($entry as node(), $lang as xs:string?) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)
    let $labels := tokenize($entry/parent::TEI:entry//TEI:usg, '\s+')
    let $dialects :=
        for $e in doc($config:taxonomies-root || "/dialects.xml")//TEI:category[@xml:id=$labels]/TEI:catDesc
        (: filtering moved to output because otherwise an error occurs :)
        return $e[@ana="full"][@xml:lang='en']
    
    let $content:= string-join($dialects, ', ')
    return $content
(:        if($pos) then <span class="invisible">{$content}</span> else $content:)
};

declare
function names:entry-attestations($entry as node()) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)

    let $name := $entry/parent::TEI:entry//TEI:orth[@type='greek']
    let $content := count(collection($config:data-root)//TEI:persName[@type="main"][.=$name])

    return 
        if($pos) then <span class="invisible">{$content}</span> else $content
};

declare
function names:entry-period($entry as node()) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)

    let $name := $entry/parent::TEI:entry//TEI:orth[@type='greek']/string()
    let $dates :=(
        min(doc($config:lgpn-volumes)//TEI:persName[@type="main"][.=$name]/parent::TEI:person/TEI:birth/@notBefore[string(.)]),
        max(doc($config:lgpn-volumes)//TEI:persName[@type="main"][.=$name]/parent::TEI:person/TEI:birth/@notAfter[string(.)]))
    let $content := string-join($dates, '/')
    return 
        if($pos) then <span class="invisible">{$content}</span> else $content
};

declare
function names:entry-gender($entry as node()) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)
    let $name := $entry/parent::TEI:entry//TEI:orth[@type='greek']
    let $genders :=
        for $g in distinct-values(doc($config:lgpn-volumes)//TEI:persName[@type="main"][.=$name]/parent::TEI:person/TEI:sex/@value/string())
        return if (number($g)=2) then "f." else "m."
    let $content:= string-join($genders, '|')
    return 
        if($pos) then <span class="invisible">{$content}</span> else $content
};

declare
function names:entry-morpheme($entry as node(), $type as xs:string, $position as xs:integer?) {
        let $bold := if ($type='radical' or $position=1) then 'font-weight: bold;' else ()
        let $class :=  if (count($entry/preceding-sibling::TEI:gramGrp)) then 'dimmed' else () 

    return <span>
        {attribute style {$bold}}
        {attribute class {$class}}
        {
(:            if($type="radical") then :)
                data(doc($config:taxonomies-root || "/morphemes.xml")//TEI:category[@baseForm=$entry//TEI:m[@type=$type][@n=$position]/@baseForm]/TEI:catDesc) 
(:            else data($entry//TEI:m[@type=$type][@n=$position]):)
        }
        </span>
};

declare
function names:entry-morpheme-functions($entry as node(), $type as xs:string) {
    let $class :=  if (count($entry/preceding-sibling::TEI:gramGrp)) then 'dimmed' else () 

(:   combining following two lines into one results in false positives returned, see low hypothesis for Alketēs,
 : https://github.com/eXistSolutions/LGPN-ling/issues/300
     let $typeMorphemes:= $entry/descendant-or-self::TEI:m[@type='radical']
: 	:)
    let $typeMorphemes := $entry//TEI:m
    let $typeMorphemes:= $typeMorphemes/descendant-or-self::TEI:m[@type!='suffix']
    let $functions := 
                for $e in $typeMorphemes/@function[string(.)]
                order by $e/@n
                return $e
    
    let $labels := doc($config:dictionaries-root || '/classification.xml')
    let $morphemes := for $m in $typeMorphemes return 
        ($m/@subtype, if(string($m/@ana)) then $m/@ana else ())
    let $headedness := string-join(($morphemes , $labels//id($entry/@type)), '')
    let $other := $entry/@ana
    let $parens := if(string($headedness) or string($other)) then '(' || string-join(($headedness, if(string($other)) then $other else ()), ' ') || ')' else ()
    return 
        <span>
            {attribute class {$class}}
            {string-join($functions, '-')}
            {if($parens) then (<br/>, $parens) else ()}
        </span>
};


declare
function names:entry-semantics($entry as node(), $lang as xs:string?) {
    let $class :=  if (count($entry/preceding-sibling::TEI:gramGrp)) then 'dimmed' else () 

    let $functions := 
            for $bf in $entry//TEI:m[@type=('radical', 'prefix')]/@baseForm[string(.)]
                let $concept :=
                    for $m in tokenize(doc($config:taxonomies-root || "/morphemes.xml")//TEI:category[@baseForm=$bf]/@ana, '\s*#')
                    return doc($config:taxonomies-root || "/ontology.xml")//TEI:category[@xml:id=$m]/TEI:catDesc[@xml:lang=$lang]
            return string-join($concept, ', ')
    return
        <span>
            {attribute class {$class}}
            {string-join($functions, '-')}
        </span>
};

declare function names:reference-entry($entry, $type) {
    let $q := if($type='cit')
        then <i style="margin-right: 0.5em;">{$entry/TEI:quote/string()}</i>
        else ()

    let $author := if ($entry/TEI:author/string()) then $entry/TEI:author/string() || ' ' else ()
    let $ref := <i style="margin-right: 0.5em;">{$entry/TEI:ref/string()}</i>
    let $rest := $entry/TEI:span/string()
    let $source := 
        if ($entry/TEI:ref/string(@target)) 
            then <a href="{$entry/TEI:ref/@target}">{$author}{$ref} {$rest}</a> 
            else ($author, $ref, $rest)
    return ($q, $source)    
};

declare
function names:entry-bibl($entry as node()) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)
    let $content := 
        for $e in $entry/parent::TEI:entry//TEI:bibl
(:        [@type='linguistic']:)
            let $source := names:reference-entry($e, 'bibl')
        return if ($e/@type='linguistic') then <p>{$source}</p> else ()
    return 
        if($pos) then <span class="invisible">{$content}</span> else $content
};

declare
function names:entry-sources($entry as node()) {
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)

    (: sources :)
    let $sources := 
        for $e in $entry/parent::TEI:entry//TEI:cit[string(.)]
        let $source := names:reference-entry($e, 'cit')
        return <p>{$source}</p>

    (: lexicographic references :)
    let $lexicographic := 
        for $e in $entry/parent::TEI:entry//TEI:bibl[string(.)]
(:        [@type='auxiliary']:)
            let $source := names:reference-entry($e, 'bibl')
        return if ($e/@type='auxiliary') then <p>{$source}</p> else ()
(:      removing cf label, needs to be replaced with special form elements :)
    let $cf := if(not(empty($sources))) then () else ()
    let $content := ($sources, if(not(empty($lexicographic))) then  ($cf, $lexicographic) else ())
    return 
        if($pos) then <span class="invisible">{$content}</span> else $content
};


declare
function names:entry-action($entry as node(), $action as xs:string?) {
    let $user := request:get-attribute("org.exist.lgpn-ling.user")
    return
        if ($user) then
    
    let $pos := count($entry/preceding-sibling::TEI:gramGrp)
    let $action:=  if($action='delete') then 
        <div>
            <form method="POST" action="">
                <input type="hidden" name="delete" value="{data($entry/parent::TEI:entry/@xml:id)}"/>
                <button class="glyphicon glyphicon-trash btn btn-xs btn-danger" type="submit" onClick="return window.confirm('Are you sure you want to delete {data($entry/parent::TEI:entry//TEI:orth[@type="greek"])}?')" data-title="Delete Name {data($entry/parent::TEI:entry//TEI:orth[@type="greek"])}">
                 Delete
                </button>
            </form>
            </div>
        else   
            <a href="editor.xhtml?id={data($entry/parent::TEI:entry/@xml:id)}"><span class="glyphicon glyphicon-edit"/></a>
    return 
        <td>
        {
            if(not($pos)) then
                $action
            else ()
        }
        </td>
    else
        ()
};