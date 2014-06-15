Currently, when generating an "id" because of missing/duplicate
message-id header, the location of the mail (path to the mbox, and
position) is used. This is dependent on how the path is specified
(absolute, relative etc.), also messages with +- identical content are
not noticed as being the same thing. (See also
[message identification](//message_identification.md).)

Instead, hash selected message headers and entities, so as to stay
independent from source of message, and avoid duplicates from getting
into the output if they miss message-id, also avoid giving a warning
if the message *does* have a message-id and is indeed virtually
identical.

Cost: $120.
