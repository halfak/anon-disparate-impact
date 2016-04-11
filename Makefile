datasets/enwiki.rev_damaging.20k_2015.tsv:
	editquality fetch_labels \
		https://labels.wmflabs.org/campaigns/enwiki/4/ \
		damaging \
		--default=False > \
	datasets/enwiki.rev_damaging.20k_2015.tsv

datasets/enwiki.rev_damaging.balanced_2k.tsv: \
		datasets/enwiki.rev_damaging.20k_2015.tsv
	(echo "rev_id\tdamaging"; \
	 cat datasets/enwiki.rev_damaging.20k_2015.tsv | \
	 grep True | shuf -n 1000; \
	 cat datasets/enwiki.rev_damaging.20k_2015.tsv | \
         grep False | shuf -n 1000) > \
	datasets/enwiki.rev_damaging.balanced_2k_sample.tsv

datasets/enwiki.rev_scores.balanced_2k.tsv: \
		datasets/enwiki.rev_damaging.balanced_2k.tsv
	cat datasets/enwiki.rev_damaging.balanced_2k.tsv | \
	python score_revisions.py > \
	datasets/enwiki.rev_scores.balanced_2k.tsv
