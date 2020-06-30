const jsonld = {
  // Add as the respecConfig localBiblio variable
  // Extend or override global respec references
  localBiblio: {
    // aliases to known references
    "JSON-LD10": {
      title: "JSON-LD 1.0",
      href: "https://www.w3.org/TR/2014/REC-json-ld-20140116/",
      publisher: "W3C",
      date: "16 January 2014",
      status: "W3C Recommendation",
      authors: [
        "Manu Sporny",
        "Gregg Kellogg",
        "Marcus Langhaler"
      ]
    },
    "JSON-LD10-API": {
      title: "JSON-LD 1.0 Processing Algorithms And API",
      href: "https://www.w3.org/TR/2014/REC-json-ld-api-20140116/",
      publisher: "W3C",
      date: "16 January 2014",
      status: "W3C Recommendation",
      authors: [
        "Marcus Langhaler",
        "Gregg Kellogg",
        "Manu Sporny"
      ]
    },
    "JSON-LD10-FRAMING": {
      title: "JSON-LD Framing 1.0",
      href: "https://json-ld.org/spec/ED/json-ld-framing/20120830/",
      publisher: "W3C",
      date: "30 August 2012",
      status: "Unofficial Draft",
      authors: [
        "Manu Sporny",
        "Gregg Kellogg",
        "David Longley",
        "Marcus Langhaler"
      ]
    },
    "IEEE-754-2008": {
      title: "IEEE 754-2008 Standard for Floating-Point Arithmetic",
      href: "http://standards.ieee.org/findstds/standard/754-2008.html",
      publisher: "Institute of Electrical and Electronics Engineers",
      date: "2008"
    },
    "JSON.API": {
      title: "JSON API",
      href: "https://jsonapi.org/format/",
      authors: [
        'Steve Klabnik',
        'Yehuda Katz',
        'Dan Gebhardt',
        'Tyler Kellen',
        'Ethan Resnick'
      ],
      status: 'unofficial',
      date: '29 May 2015'
    },
    "RFC8785": {
      title: "JSON Canonicalization Scheme (JCS)",
      href: 'https://www.rfc-editor.org/rfc/rfc8785',
      authors: ['A. Rundgren', 'B. Jordan', 'S. Erdtman'],
      publisher: 'Network Working Group',
      status: 'Informational',
      date: 'June 2020'
    },
    // These necessary as specref uses the wrong URLs
    "RFC7231": {
      title: 'Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content',
      href: 'https://tools.ietf.org/html/rfc7231',
      authors: ['R. Fielding, Ed.', 'J. Reschke, Ed'],
      pubisher: 'IETF',
      status: 'Proposed Standard',
      date: 'June 2014'
    },
    "RFC8288": {
      title: 'Web Linking',
      href: 'https://tools.ietf.org/html/rfc8288',
      authors: ['M. Nottingham'],
      pubisher: 'IETF',
      status: 'Proposed Standard',
      date: 'October 2017'
    },
  }
};
