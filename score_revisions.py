"""
Scores a set of edits by whether or not they are damaging.

Usage:
    score_damaging <model-file> --host=<url>
                   [--cache=<json>]
                   [--verbose] [--debug]

Arguments:
    <model-file>    The database name of the wiki to look for <model>

Options:
    -h --help       Prints this documentation
    --host=<url>    The base URL to the MediaWiki installation to use when
                    extracting features
    --cache=<json>  JSON blob with cached values to use when extracting
                    features
    --verbose       Prints dots and stuff that represent progress
    --debug         Prints debug logging
"""
import json
import logging
import sys

import docopt
import mwapi
from revscoring import ScoreProcessor
from revscoring.extractors import api
from revscoring.scorer_models import MLScorerModel

import mysqltsv


def main():
    args = docopt.docopt(__doc__)

    logging.basicConfig(
        level=logging.DEBUG if args['--debug'] else logging.INFO,
        format='%(asctime)s %(levelname)s:%(name)s -- %(message)s'
    )
    logging.getLogger('requests').setLevel(logging.WARNING)

    rev_ids = (int(r.rev_id) for r in mysqltsv.read(sys.stdin))

    scorer_model = MLScorerModel.load(open(args['<model-file>']))
    session = mwapi.Session(
        args['--host'], user_agent="Anon bias study <ahalfaker@wikimedia.org>")
    extractor = api.Extractor(session)
    score_processor = ScoreProcessor(scorer_model, extractor)

    cache = json.loads(args['--cache'] or "{}")

    verbose = args['--verbose']
    debug = args['--debug']

    run(rev_ids, score_processor, cache, verbose, debug)


def run(rev_ids, score_processor, cache, verbose, debug):

    writer = mysqltsv.Writer(sys.stdout, headers=['rev_id', 'true_proba'])

    for rev_id, score in score_processor.score(rev_ids, cache=cache):
        if 'type' in score:
            sys.stderr.write("e")
        elif 'probability' in score:
            writer.write([rev_id, score['probability'][True]])
            sys.stderr.write(".")
        else:
            sys.stderr.write(json.dumps(score))

        sys.stderr.flush()

    sys.stderr.write("\n")


if __name__ == "__main__":
    main()
