/* globals require */
/* JSON-LD Working Group common spec JavaScript */

/*
* Implement tabbed examples.
*/
require(["core/pubsubhub"], (respecEvents) => {
  "use strict";

  respecEvents.sub('end-all', (documentElement) => {
    // remove data-cite on where the citation is to ourselves.
    const selfDfns = document.querySelectorAll("dfn[data-cite^='__SPEC__#']");
    for (const dfn of selfDfns) {
      const anchor = dfn.querySelector('a');
      if (anchor) {
        const anchorContent = anchor.textContent;
        dfn.removeChild(anchor);
        dfn.textContent = anchorContent;
      }
      delete dfn.dataset.cite;
    }

    // Update data-cite references to ourselves.
    const selfRefs = document.querySelectorAll("a[data-cite^='__SPEC__#']");
    for (const anchor of selfRefs) {
      anchor.href= anchor.dataset.cite.replace(/^.*#/,"#");
      delete anchor.dataset.cite;
    }

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
