const jsonld = {
  // Add as the respecConfig localBiblio variable
  // Extend or override global respec references
  localBiblio: {
    "JSON-LD11": {
      title: "JSON-LD 1.1",
      href: "https://w3c.github.io/json-ld-syntax/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'FPWD',
      date: '06 September 2018'
    },
    "JSON-LD11-API": {
      title: "JSON-LD 1.1 Processing Algorithms and API",
      href: "https://w3c.github.io/json-ld-api/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'FPWD',
      date: '06 September 2018'
    },
    "JSON-LD11-FRAMING": {
      title: "JSON-LD 1.1 Framing",
      href: "https://w3c.github.io/json-ld-framing/",
      authors: ["Gregg Kellogg"],
      publisher: "W3C",
      status: 'FPWD',
      date: '06 September 2018'
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
    }
  },
  conversions: {
    "https://w3c.github.io/json-ld-syntax/": "http://www.w3.org/TR/2018/WD-json-ld11-syntax-20180911/",
    "https://w3c.github.io/json-ld-api/": "http://www.w3.org/TR/2018/WD-json-ld11-api-20180911/",
    "https://w3c.github.io/json-ld-framing/": "http://www.w3.org/TR/2018/WD-json-ld11-framing-20180911/"
  }
};
