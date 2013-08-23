The basic principle of operation of ml2json is the following:

A) ml2json iterates over all the *.mbox files in the given directory,
opening each file in turn, iterating over the messages therein,
parsing each in turn using the MIME parser which creates an object
plus files in the tmp directory; the code then serializes the object
to the tmp directory as well, so that the parsed state can be resumed
multiple times quickly. Each object representing the collection of
messages of an individual mbox is serialized as well. The path of each
*.mbox object is hashed using md5 and used that way as part of the tmp
path. If there's already a serialized object for a message collection
object representing an mbox, the mbox isn't parsed again but just the
object deserialized (that's why subsequent runs of the script will be
faster, also there will be less warnings then). The whole directory is
also represented as a messagecollection object (a subclass specific
for dirs).

B) it then iterates over the messages in the (toplevel, i.e. directory)
messagecollection object, de-serializing each parsed message object in
turn, and builds an index of the messageids and replies,

C) after that, it creates a sorted list of messages, grouped by thread
and sorted according to the last reply of a thread, and iterates
through that, deserializing each parsed message once again in turn and
printing it as JSON (possibly saving message/rfc822 parts as another
file so that it too can be accessed as a file).


For this reason, if changes to the code were done that lead to changed
results from phase A, the changes will only be seen if phase A is
being forced to run again by eliminating its result from disk by
running ml2json --cleanup, first.
