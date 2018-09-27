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
    .replace(/< !--/g, '<!--')
    .replace(/-- >/g, '-->');
}
