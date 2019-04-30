There are two files that are created for each document:
the explicit list in separate_acks.json which lists those that are to be mentioned as really authors and contributors.
a template file in ack_pattern.html that contains the slots for the two lists: the ones called out explicitly, and all the others. This will be documented, but it is fairly self-evident.

The acknowledgements.html file is included into the ReSpec document using:

    <section id="ack"
             class="appendix informative"
             data-include="ack-script/acknowledgements.html"
             data-include-replace="true">
    </section>

To rebuild the acknowledgements file
create a ~/.publ_ack.json which should include, at the minimum,
the api_key for accessing the W3C API-s that gives one access to these data (see https://w3c.github.io/w3c-api/).
