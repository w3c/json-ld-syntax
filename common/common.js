/* globals omitTerms, respecConfig, $, require */
/* JSON-LD Working Group common spec JavaScript */
// We should be able to remove terms that are not actually
// referenced from the common definitions
//
// Add class "preserve" to a definition to ensure it is not removed.
//
// the termlist is in a block of class "termlist".
const termNames = [] ;
const termsReferencedByTerms = [] ;

function restrictReferences(utils, content) {
  const base = document.createElement("div");
  base.innerHTML = content;

  // New new logic:
  //
  // 1. build a list of all term-internal references
  // 2. When ready to process, for each reference INTO the terms,
  // remove any terms they reference from the termNames array too.
  const noPreserve = base.querySelectorAll("dfn:not(.preserve)");
  for (const item of noPreserve) {
    const $t = $(item);
    const titles = $t.getDfnTitles();
    const n = $t.makeID("dfn", titles[0]);
    if (n) {
      termNames[n] = $t.parent();
    }
  }

  const $container = $(".termlist", base) ;
  const containerID = $container.makeID("", "terms") ;
  return (base.innerHTML);
}

require(["core/pubsubhub"], (respecEvents) => {
  "use strict";

  respecEvents.sub('end', (message) => {
    // remove data-cite on where the citation is to ourselves.
    const selfDfns = document.querySelectorAll("dfn[data-cite^='" + respecConfig.shortName.toUpperCase() + "#']");
    for (const dfn of selfDfns) {
      delete dfn.dataset.cite;
    }

    // Update data-cite references to ourselves.
    const selfRefs = document.querySelectorAll("a[data-cite^='" + respecConfig.shortName.toUpperCase() + "#']");
    for (const anchor of selfRefs) {
      anchor.href= anchor.dataset.cite.replace(/^.*#/,"#");
      delete anchor.dataset.cite;
    }
  });

  // add a handler to come in after all the definitions are resolved
  //
  // New logic: If the reference is within a 'dl' element of
  // class 'termlist', and if the target of that reference is
  // also within a 'dl' element of class 'termlist', then
  // consider it an internal reference and ignore it.
  respecEvents.sub('end', (message) => {
    if (message === 'core/link-to-dfn') {
      // all definitions are linked; find any internal references
      const internalTerms = document.querySelectorAll(".termlist a.internalDFN");
      for (const item of internalTerms) {
        const idref = item.getAttribute('href').replace(/^#/,"") ;
        if (termNames[idref]) {
          // this is a reference to another term
          // what is the idref of THIS term?
          const def = item.closest('dd');
          if (def) {
            const tid = def.previousElementSibling
              .querySelector('dfn')
              .getAttribute('id');
            if (tid) {
              if (termsReferencedByTerms[tid] === undefined) termsReferencedByTerms[tid] = [];
              termsReferencedByTerms[tid].push(idref);
            }
          }
        }
      }

      // clearRefs is recursive.  Walk down the tree of
      // references to ensure that all references are resolved.
      const clearRefs = (theTerm) => {
        if (termsReferencedByTerms[theTerm] ) {
          for (const item of termsReferencedByTerms[theTerm]) {
            if (termNames[item]) {
                delete termNames[item];
                clearRefs(item);
            }
          }
        };
        // make sure this term doesn't get removed
        if (termNames[theTerm]) {
          delete termNames[theTerm];
        }
      };

      // now termsReferencedByTerms has ALL terms that
      // reference other terms, and a list of the
      // terms that they reference
      const internalRefs = document.querySelectorAll("a[data-link-type='dfn']");
      for (const item of internalRefs) {
        const idref = item.getAttribute('href').replace(/^.*#/,"") ;
        // if the item is outside the term list
        if (!item.closest('dl.termlist')) {
          clearRefs(idref);
        }
      }

      // delete any terms that were not referenced.
      for (const term in termNames) {
        const $p = $("#"+term);
        // Remove term definitions inside a dt, where data-cite does not start with shortname
        if ($p === undefined) { continue; }
        if (!$p.parent().is("dt")) { continue; }
        if (($p.data("cite") || "").toLowerCase().startsWith(respecConfig.shortName)) { continue; }

        const $dt = $p.parent();
        const $dd = $dt.next();

        // If the associated dd contains a dfn which is _not_ in termNames, warn
        if ($dd.children("dfn").length > 0) {
          console.log(term + " definition contains definitions " + $dd.children("dfn").attr("id"))
        }
        console.log("drop term " + term);
        const tList = $p.getDfnTitles();
        $dd.remove(); // remove dd
        $dt.remove(); // remove dt
        // FIXME: this depended on an undocumented internal structure
        //for (const item of tList) {
        //  if (respecConfig.definitionMap[item]) {
        //    delete respecConfig.definitionMap[item];
        //  }
        //}
      }
    }
  });
});

/*
* Implement tabbed examples.
*/
require(["core/pubsubhub"], (respecEvents) => {
  "use strict";
  respecEvents.sub('end-all', (documentElement) => {
    // Add playground links
    for (const link of document.querySelectorAll("a.playground")) {
      let pre;
      if (link.dataset.resultFor) {
        // Referenced pre element
        pre = document.querySelector(link.dataset.resultFor + ' > pre');
      } else {
        // First pre element of aside
        pre = link.closest("aside").querySelector("pre");
      }
      const content = unComment(document, pre.textContent)
        .replace(/\*\*\*\*/g, '')
        .replace(/####([^#]*)####/g, '');
      link.setAttribute('aria-label', 'playground link');
      link.textContent = "Open in playground";

      // startTab defaults to "expand"
      const linkQueryParams = {
        startTab: "tab-expand",
        "json-ld": content
      }

      if (link.dataset.compact !== undefined) {
        linkQueryParams.startTab = "tab-" + "compacted";
        linkQueryParams.context = '{}';
      }

      if (link.dataset.flatten !== undefined) {
        linkQueryParams.startTab = "tab-" + "flattened";
        linkQueryParams.context = '{}';
      }

      if (link.dataset.frame !== undefined) {
        linkQueryParams.startTab = "tab-" + "framed";
        const frameContent = unComment(document, document.querySelector(link.dataset.frame + ' > pre').textContent)
          .replace(/\*\*\*\*/g, '')
          .replace(/####([^#]*)####/g, '');
        linkQueryParams.frame = frameContent;
      }

      // Set context
      if (link.dataset.context) {
        const contextContent = unComment(document, document.querySelector(link.dataset.context + ' > pre').textContent)
          .replace(/\*\*\*\*/g, '')
          .replace(/####([^#]*)####/g, '');
        linkQueryParams.context = contextContent;
      }

      link.setAttribute('href',
        'https://json-ld.org/playground/#' +
        Object.keys(linkQueryParams).map(k => `${encodeURIComponent(k)}=${encodeURIComponent(linkQueryParams[k])}`)
              .join('&'));
    }

    // Add highlighting and remove comment from pre elements
    for (const pre of document.querySelectorAll("pre")) {
      // First pre element of aside
      const content = pre.innerHTML
        .replace(/\*\*\*\*([^*]*)\*\*\*\*/g, '<span class="hl-bold">$1</span>')
        .replace(/####([^#]*)####/g, '<span class="comment">$1</span>');
      pre.innerHTML = content;
    }
  });
});

function _esc(s) {
  return s.replace(/&/g,'&amp;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/</g,'&lt;');
}

function reindent(text) {
  // TODO: use trimEnd when Edge supports it
  const lines = text.trimRight().split("\n");
  while (lines.length && !lines[0].trim()) {
    lines.shift();
  }
  const indents = lines.filter(s => s.trim()).map(s => s.search(/[^\s]/));
  const leastIndent = Math.min(...indents);
  return lines.map(s => s.slice(leastIndent)).join("\n");
}

function updateExample(doc, content) {
  // perform transformations to make it render and prettier
  return _esc(reindent(unComment(doc, content)));
}


function unComment(doc, content) {
  // perform transformations to make it render and prettier
  return content
    .replace(/<!--/, '')
    .replace(/-->/, '')
    .replace(/< !\s*-\s*-/g, '<!--')
    .replace(/-\s*- >/g, '-->')
    .replace(/-\s*-\s*&gt;/g, '--&gt;');
}
