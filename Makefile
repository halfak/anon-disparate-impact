test_statistics = \
	-s 'table' -s 'accuracy' -s 'precision' -s 'recall' \
	-s 'pr' -s 'roc' \
	-s 'recall_at_fpr(max_fpr=0.10)' \
	-s 'filter_rate_at_recall(min_recall=0.90)' \
	-s 'filter_rate_at_recall(min_recall=0.75)'

anon_cache = \
  {"feature.revision.user.is_anon": true, \
	 "feature.temporal.revision.user.seconds_since_registration": 0 \
	 "feature.revision.user.has_advanced_rights": false, \
	 "feature.revision.user.is_admin": false, \
	 "feature.revision.user.is_bot": false, \
	 "feature.revision.user.is_curator": false}

newcomer_cache = \
	{"feature.revision.user.is_anon": false, \
	 "feature.temporal.revision.user.seconds_since_registration": 18000, \
	 "feature.revision.user.has_advanced_rights": false, \
	 "feature.revision.user.is_admin": false, \
	 "feature.revision.user.is_bot": false \
	 "feature.revision.user.is_curator": false}

epochfail_cache = \
  {"feature.revision.user.is_anon": false, \
	 "feature.temporal.revision.user.seconds_since_registration": 257995021, \
	 "feature.revision.user.has_advanced_rights": false, \
	 "feature.revision.user.is_admin": false, \
	 "feature.revision.user.is_bot": false \
	 "feature.revision.user.is_curator": false}

admin_cache = \
	{"feature.revision.user.is_anon": false, \
	 "feature.temporal.revision.user.seconds_since_registration": 257995021, \
	 "feature.revision.user.has_advanced_rights": true, \
	 "feature.revision.user.is_admin": true, \
	 "feature.revision.user.is_bot": false \
	 "feature.revision.user.is_curator": true}

data_for_analysis: \
		datasets/enwiki.rev_scores.damaging.linear_svc_balanced.tsv \
		datasets/enwiki.rev_scores.damaging.linear_svc_balanced.anon.tsv \
		datasets/enwiki.rev_scores.damaging.linear_svc_balanced.newcomer.tsv \
		datasets/enwiki.rev_scores.damaging.linear_svc_balanced.epochfail.tsv \
		datasets/enwiki.rev_scores.damaging.linear_svc_balanced.admin.tsv \
		datasets/enwiki.rev_scores.damaging.gradient_boosting.tsv \
		datasets/enwiki.rev_scores.damaging.gradient_boosting.anon.tsv \
		datasets/enwiki.rev_scores.damaging.gradient_boosting.newcomer.tsv \
		datasets/enwiki.rev_scores.damaging.gradient_boosting.epochfail.tsv \
		datasets/enwiki.rev_scores.damaging.gradient_boosting.admin.tsv

datasets/enwiki.rev_damaging.20k_2015.tsv:
	editquality fetch_labels \
		https://labels.wmflabs.org/campaigns/enwiki/4/ \
		damaging \
		--default=False | shuf > \
	datasets/enwiki.rev_damaging.20k_2015.tsv

datasets/enwiki.rev_damaging.training.15k_2015.tsv: \
		datasets/enwiki.rev_damaging.20k_2015.tsv
	head datasets/enwiki.rev_damaging.20k_2015.tsv -n 15000 > \
	datasets/enwiki.rev_damaging.training.15k_2015.tsv

datasets/enwiki.rev_damaging.testing.5k_2015.tsv: \
		datasets/enwiki.rev_damaging.20k_2015.tsv
	tail datasets/enwiki.rev_damaging.20k_2015.tsv -n+15001 > \
	datasets/enwiki.rev_damaging.testing.5k_2015.tsv

datasets/enwiki.features_damaging.training.15k_2015.tsv: \
		datasets/enwiki.rev_damaging.training.15k_2015.tsv
	cat datasets/enwiki.rev_damaging.training.15k_2015.tsv | \
	revscoring extract_features \
		editquality.feature_lists.enwiki.damaging \
		--host https://en.wikipedia.org \
		--include-revid \
		--verbose > \
	datasets/enwiki.features_damaging.training.15k_2015.tsv

datasets/enwiki.features_damaging.testing.5k_2015.tsv: \
		datasets/enwiki.rev_damaging.testing.5k_2015.tsv
	cat datasets/enwiki.rev_damaging.testing.5k_2015.tsv | \
	revscoring extract_features \
		editquality.feature_lists.enwiki.damaging \
		--host https://en.wikipedia.org \
		--include-revid \
		--verbose > \
	datasets/enwiki.features_damaging.testing.5k_2015.tsv

models/enwiki.damaging.linear_svc_balanced.raw.model: \
		datasets/enwiki.features_damaging.training.15k_2015.tsv
	cut datasets/enwiki.features_damaging.training.15k_2015.tsv -f2- | \
	revscoring train_model \
		revscoring.scorer_models.LinearSVC \
		editquality.feature_lists.enwiki.damaging \
		--version="bias experiment" \
		-p 'cache_size=100000' \
		--balance-sample \
		--center --scale \
		--label-type=bool > \
	models/enwiki.damaging.linear_svc_balanced.raw.model

models/enwiki.damaging.linear_svc_balanced.model: \
		models/enwiki.damaging.linear_svc_balanced.raw.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	cat datasets/enwiki.features_damaging.testing.5k_2015.tsv -f2- | \
	revscoring test_model \
		models/enwiki.damaging.linear_svc_balanced.raw.model \
		$(test_statistics) \
		--label-type=bool > \
	models/enwiki.damaging.linear_svc_balanced.model

models/enwiki.damaging.gradient_boosting.raw.model: \
		datasets/enwiki.features_damaging.training.15k_2015.tsv
	cut datasets/enwiki.features_damaging.training.15k_2015.tsv -f2- | \
	revscoring train_model \
		revscoring.scorer_models.GradientBoosting \
		editquality.feature_lists.enwiki.damaging \
		--version="bias experiment" \
		-p 'max_depth=7' \
		-p 'learning_rate=0.01' \
		-p 'max_features="log2"' \
		-p 'n_estimators=700' \
		--balance-sample-weight \
		--center --scale \
		--label-type=bool > \
	models/enwiki.damaging.gradient_boosting.raw.model

models/enwiki.damaging.gradient_boosting.model: \
		models/enwiki.damaging.gradient_boosting.raw.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	cat datasets/enwiki.features_damaging.testing.5k_2015.tsv -f2- | \
	revscoring test_model \
		models/enwiki.damaging.gradient_boosting.raw.model \
		$(test_statistics) \
		--label-type=bool > \
	models/enwiki.damaging.gradient_boosting.model

datasets/enwiki.rev_scores.damaging.linear_svc_balanced.tsv: \
		models/enwiki.damaging.linear_svc_balanced.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.linear_svc_balanced.model \
		--host https://en.wikipedia.org > \
	datasets/enwiki.rev_scores.damaging.linear_svc_balanced.tsv

datasets/enwiki.rev_scores.damaging.linear_svc_balanced.anon.tsv: \
		models/enwiki.damaging.linear_svc_balanced.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.linear_svc_balanced.model \
		--host https://en.wikipedia.org \
		--cache $(anon_cache) > \
	datasets/enwiki.rev_scores.damaging.linear_svc_balanced.anon.tsv

datasets/enwiki.rev_scores.damaging.linear_svc_balanced.newcomer.tsv: \
		models/enwiki.damaging.linear_svc_balanced.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.linear_svc_balanced.model \
		--host https://en.wikipedia.org \
		--cache $(newcomer_cache) > \
	datasets/enwiki.rev_scores.damaging.linear_svc_balanced.newcomer.tsv

datasets/enwiki.rev_scores.damaging.linear_svc_balanced.epochfail.tsv: \
		models/enwiki.damaging.linear_svc_balanced.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.linear_svc_balanced.model \
		--host https://en.wikipedia.org \
		--cache $(epochfail_cache) > \
	datasets/enwiki.rev_scores.damaging.linear_svc_balanced.epochfail.tsv

datasets/enwiki.rev_scores.damaging.linear_svc_balanced.admin.tsv: \
		models/enwiki.damaging.linear_svc_balanced.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.linear_svc_balanced.model \
		--host https://en.wikipedia.org \
		--cache $(admin_cache) > \
	datasets/enwiki.rev_scores.damaging.linear_svc_balanced.admin.tsv

datasets/enwiki.rev_scores.damaging.gradient_boosting.tsv: \
		models/enwiki.damaging.gradient_boosting.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.gradient_boosting.model \
		--host https://en.wikipedia.org > \
	datasets/enwiki.rev_scores.damaging.gradient_boosting.tsv

datasets/enwiki.rev_scores.damaging.gradient_boosting.anon.tsv: \
		models/enwiki.damaging.gradient_boosting.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.gradient_boosting.model \
		--host https://en.wikipedia.org \
		--cache $(anon_cache) > \
	datasets/enwiki.rev_scores.damaging.gradient_boosting.anon.tsv

datasets/enwiki.rev_scores.damaging.gradient_boosting.newcomer.tsv: \
		models/enwiki.damaging.gradient_boosting.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.gradient_boosting.model \
		--host https://en.wikipedia.org \
		--cache $(newcomer_cache) > \
	datasets/enwiki.rev_scores.damaging.gradient_boosting.newcomer.tsv

datasets/enwiki.rev_scores.damaging.gradient_boosting.epochfail.tsv: \
		models/enwiki.damaging.gradient_boosting.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.gradient_boosting.model \
		--host https://en.wikipedia.org \
		--cache $(epochfail_cache) > \
	datasets/enwiki.rev_scores.damaging.gradient_boosting.epochfail.tsv

datasets/enwiki.rev_scores.damaging.gradient_boosting.admin.tsv: \
		models/enwiki.damaging.gradient_boosting.model \
		datasets/enwiki.features_damaging.testing.5k_2015.tsv
	(echo "rev_id\tdamaging";
	 cat models/enwiki.rev_damaging.testing.5k_2015.tsv) | \
	python score_revisions.py \
		models/enwiki.damaging.gradient_boosting.model \
		--host https://en.wikipedia.org \
		--cache $(admin_cache) > \
	datasets/enwiki.rev_scores.damaging.gradient_boosting.admin.tsv
