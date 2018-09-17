const jsonld = {
  // Add as the respecConfig localBiblio variable
  // Extend or override global respec references
  localBiblio: {
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
    "https://w3c.github.io/json-ld-syntax/": "http://www.w3.org/TR/json-ld11/",
    "https://w3c.github.io/json-ld-api/": "http://www.w3.org/TR/json-ld11-api/",
    "https://w3c.github.io/json-ld-framing/": "http://www.w3.org/TR/json-ld11-framing/"
  }
};
