const jsonld = {
  // Add as the respecConfig localBiblio variable
  // Extend or override global respec references
  localBiblio: {
    "JSON-LD11": {
      title: "JSON-LD 1.1",
      href: "https://w3c.github.io/json-ld-syntax/",
      authors: ["Gregg Kellogg", "Pierre-Antoine Champin"],
      publisher: "W3C",
      status: 'FPWD',
      date: '10 May 2019'
    },
    "JSON-LD11-API": {
      title: "JSON-LD 1.1 Processing Algorithms and API",
      href: "https://w3c.github.io/json-ld-api/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'FPWD',
      date: '10 May 2019'
    },
    "JSON-LD11-FRAMING": {
      title: "JSON-LD 1.1 Framing",
      href: "https://w3c.github.io/json-ld-framing/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'FPWD',
      date: '10 May 2019'
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
    "JCS": {
      title: "JSON Canonicalization Scheme (JCS)",
      href: 'https://tools.ietf.org/html/draft-rundgren-json-canonicalization-scheme-05',
      authors: ['A. Rundgren', 'B. Jordan', 'S. Erdtman'],
      publisher: 'Network Working Group',
      status: 'Internet-Draft',
      date: 'February 16, 2019'
    }
  },
  conversions: {
    "https://w3c.github.io/json-ld-syntax/": "http://www.w3.org/TR/json-ld11/",
    "https://w3c.github.io/json-ld-api/": "http://www.w3.org/TR/json-ld11-api/",
    "https://w3c.github.io/json-ld-framing/": "http://www.w3.org/TR/json-ld11-framing/"
  }
};
