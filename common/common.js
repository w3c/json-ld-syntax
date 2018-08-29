/* globals omitTerms, respecConfig, $, require */
/* JSON-LD Working Group common spec JavaScript */
// We should be able to remove terms that are not actually
// referenced from the common definitions
//
// Add class "preserve" to a definition to ensure it is not removed.
//
// the termlist is in a block of class "termlist", so make sure that
// has an ID and put that ID into the termLists array so we can
// interrogate all of the included termlists later.
const termNames = [] ;
const termLists = [] ;
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
    const $t = $(item) ;
    const titles = $t.getDfnTitles();
    const n = $t.makeID("dfn", titles[0]);
    if (n) {
      termNames[n] = $t.parent();
    }
  }

  const $container = $(".termlist", base) ;
  const containerID = $container.makeID("", "terms") ;
  termLists.push(containerID) ;
  return (base.innerHTML);
}

// add a handler to come in after all the definitions are resolved
//
// New logic: If the reference is within a 'dl' element of
// class 'termlist', and if the target of that reference is
// also within a 'dl' element of class 'termlist', then
// consider it an internal reference and ignore it.
require(["core/pubsubhub"], function(respecEvents) {
  "use strict";
  respecEvents.sub('end', function(message) {
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
      const clearRefs = function(theTerm) {
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
      const internalRefs = document.querySelectorAll("a.internalDFN");
      for (const item of internalRefs) {
        const idref = item.getAttribute('href').replace(/^#/,"") ;
        // if the item is outside the term list
        if (!item.closest('dl.termlist')) {
          clearRefs(idref);
        }
      }

      // delete any terms that were not referenced.
      for (const term in termNames) {
        const $p = $("#"+term) ;
        if ($p) {
          const tList = $p.getDfnTitles();
          $p.parent().next().remove(); // remove dd
          $p.remove();                 // remove dt
          for (const item of tList) {
            if (respecConfig.definitionMap[item]) {
              delete respecConfig.definitionMap[item];
            }
          }
        }
      }
    }
  });
});

/*
*
* Replace github.io references to /TR references.
* The issue is as follows: when several specs are developed in parallel, it is a good idea
* to use, for mutual references, the github.io URI-s. That ensures that the editors' drafts are always
* correct in terms of mutual references.
*
* However, when publishing the documents, all those references must be exchanged against the final, /TR
* URI-s. That process, when done manually, is boring and error prone. This script solves the issue:
*
* * Create a separate file with the 'conversions' array. See, e.g., https://github.com/w3c/csvw/blob/gh-pages/local-biblio.js
*   for an example.
* * Include a reference to that file and this to the respec code, after the inclusion of respec. E.g.:
* ```
*  <script class="remove" src="../local-biblio.js"></script>
*  <script class="remove" src="https://www.w3.org/Tools/respec/respec-w3c-common"></script>
*  <script class="remove" src="../replace-ed-uris.js"></script>
* ```
*
* This function will be automatically executed when the respec source is saved in an (X)HTML file.
* Note that
*
* * Links in the header part will *not* be changed. That part is usually generated automatically, and the reference to the
*   editor's draft must stay unchanged
* * The text content of an <a> element will also be converted (if needed). This means that the reference list may also
*   use include the github.io address (as it should...)
*
*/
require(["core/pubsubhub"], function(respecEvents) {
  "use strict";
  respecEvents.sub('beforesave', function(documentElement) {
    $("a[href]", documentElement).each( function(index) {
      // Don't rewrite these.
      if ($(this, documentElement).closest('dd').prev().text().match(/Latest editor|Test suite|Implementation report/)) return;
      const href = $(this, documentElement).attr("href");
      for (const toReplace in jsonld.conversions) {
        if (href.indexOf(toReplace) !== -1) {
          const replacement = jsonld.conversions[toReplace];
          const newHref = href.replace(toReplace, replacement);
          $(this, documentElement).attr("href", newHref);
          if( $(this, documentElement).text().indexOf(toReplace) !== -1 ) {
            $(this, documentElement).text($(this, documentElement).text().replace(toReplace, replacement));
          }
        }
      }
    });
  });
});

function _esc(s) {
  return s.replace(/&/g,'&amp;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/</g,'&lt;');
}

function updateExample(doc, content) {
  // perform transformations to make it render and prettier
  return _esc(unComment(doc, content))
    .replace(/\*\*\*\*([^*]*)\*\*\*\*/g, '<span class="hl-bold">$1</span>')
    .replace(/####([^#]*)####/g, '<span class="comment">$1</span>');
}


function unComment(doc, content) {
  // perform transformations to make it render and prettier
  return content.replace(/<!--/, '')
    .replace(/-->/, '');
}
