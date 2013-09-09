* add JSONPath support for field extraction. Cost: $4
* add Excel .xls output. Cost: $4
* handle multiple values: see below.

---

On how to handle multiple values, there are these 4 possible ways:

0. drop them. Using a JSONPath like "parsed_from[0].address" means, take the first one, drop the others.

1. denormalization. Meaning,  [{A:"a",B:"b",C:["c1","c2"],D:"d"}] is turned into the CSV

        A;B;C;D
        a;b;c1;d
        a;b;c2;d

    (Usually you don't want to denormalize data, as it uses more space and will be a pain to further process correctly, but could be viable in some cases.)

    Cost: $30.

2. relational data model, using multiple CSV output files.  [{a:"a",b:"b",c:["c1","c2"],d:"d"}] is turned into:

      main.csv:

        ID;A;B;D
        1234;a;b;d

      C.csv:

        MAINID;C
        1234;c1
        1234;c2

    The json2csv script would probably take options to declare which columns should be split off into their own files. And if there are multiple values for a column for which the option has not been given, give an error.

    Cost: $30.

3. carry over nesting by encoding into strings; for example, [{a:"a",b:"b",c:["c1","c2"],d:"d"}] is turned into:

        A;B;C;D
        a;b;"[\"c1\",\"c2\"]";d

    Here using JSON encoding for the nested data. JSON is nice since it allows infinitely deep nesting ;). Custom encoding (serialization format) could be something like 

        A;B;C;D
        a;b;c1.c2;d

    but one would only do that if invention of new serialization formats is necessary (like Excel not having functions to parse JSON fragments).

    JSON: Cost: $25. Custom format: Cost: $30.

