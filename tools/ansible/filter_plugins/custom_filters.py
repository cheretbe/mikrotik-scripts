#!/usr/bin/env python3

# import pprint

class FilterModule(object):

    def filters(self):
        return {
            'ms_comment_multiline_string': self.ms_comment_multiline_string,
        }

    def ms_comment_multiline_string(self, source_string):
        line_elements = source_string.split("\n")
        if len(line_elements) == 1:
            return source_string
        else:
            return (line_elements[0] + '\n' + '\n'.join(f"# {le}" for le in line_elements[1:]))
