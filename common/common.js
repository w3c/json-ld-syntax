/* Web Payments Community Group common spec JavaScript */
const jsonld = {
  // Add as the respecConfig localBiblio variable
  // Extend or override global respec references
  localBiblio: {
    "JSON-LD11": {
      title: "JSON-LD 1.1",
      href: "https://w3c.github.io/json-ld-syntax/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'ED'
    },
    "JSON-LD11-API": {
      title: "JSON-LD 1.1 Processing Algorithms and API",
      href: "https://w3c.github.io/json-ld-api/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'ED'
    },
    "JSON-LD11-FRAMING": {
      title: "JSON-LD 1.1 Framing",
      href: "https://w3c.github.io/json-ld-framing/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'ED'
    },
    "JSON-LD-TESTS": {
      title: "JSON-LD 1.1 Test Suite",
      href: "https://json-ld.org/test-suite/",
      authors: ["Gregg Kellogg"],
      publisher: "Linking Data in JSON Community Group"
    },
    // aliases to known references
    "IEEE-754-2008": {
      title: "IEEE 754-2008 Standard for Floating-Point Arithmetic",
      href: "http://standards.ieee.org/findstds/standard/754-2008.html",
      publisher: "Institute of Electrical and Electronics Engineers",
      date: "2008"
    },
    "PROMISES": {
      title: 'Promise Objects',
      href: 'https://github.com/domenic/promises-unwrapping',
      authors: ['Domenic Denicola'],
      status: 'unofficial',
      date: 'January 2014'
    },
    "MICROFORMATS": {
      title: "Microformats",
      href: "http://microformats.org"
    }
  }
};

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

function internalizeTermListReferences() {
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
          if (termsReferencedByTerms[tid]) {
            termsReferencedByTerms[tid].push(idref);
          } else {
            termsReferencedByTerms[tid] = [] ;
            termsReferencedByTerms[tid].push(idref);
          }
        }
      }
    }
  }

  // clearRefs is recursive.  Walk down the tree of
  // references to ensure that all references are resolved.
  const clearRefs = function(theTerm) {
    if ( termsReferencedByTerms[theTerm] ) {
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
    if ( !item.closest('dl.termlist') ) {
      clearRefs(idref);
    }
  }

  // delete any terms that were not referenced.
  Object.keys(termNames).forEach(function(term) {
    const $p = $("#"+term) ;
    if ($p) {
      const tList = $p.getDfnTitles();
      $p.parent().next().remove();
      $p.remove() ;
      tList.forEach(function( item ) {
        if (respecConfig.definitionMap[item]) {
          delete respecConfig.definitionMap[item];
        }
      });
    }
  });
}

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
