Messages are identified in two ways:

 * "id", their message ID, in the source code called just `id` (as
   opposed to `message_id`), which is the message's "Message-ID" field
   value if usable (i.e. there is exactly one such header, and it has
   some non-empty content), or a newly created ID to take its
   place. Meant to identify a particular *post*. Newly created IDs are
   currently using the identify string as described below. See
   [Todo](../TODO.md) for suggestions to change this.

 * "identify" string: identification of the mbox and the index of the
   message therein. Can be used to find the original message
   unambiguously, see ml2json --deidentify option. In cases where the
   same post appears multiple times in the same or different mbox
   files, there will be multiple "identify" values, but only one and
   the same "id" value; a WARN will be issued if that happens and all
   except one instance of the post will be ignored.

        identify = md5(path_to_the_mbox) + "/" + position_within_the_mbox

   Note that `path_to_the_mbox` is not expanded (made absolute), but
   directly derived from the source path given to ml2json. See
   [Todo](../TODO.md) for suggestions to change this.
