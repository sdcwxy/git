#!/bin/sh

test_description='test the `scalar` command'

TEST_DIRECTORY=$(pwd)/../../../t
export TEST_DIRECTORY

# Make it work with --no-bin-wrappers
PATH=$(pwd)/..:$PATH

. ../../../t/test-lib.sh

GIT_TEST_MAINT_SCHEDULER="crontab:test-tool crontab ../cron.txt"
export GIT_TEST_MAINT_SCHEDULER

test_expect_success 'scalar shows a usage' '
	test_expect_code 129 scalar -h
'

test_expect_success 'set up repository to clone' '
	test_commit first &&
	test_commit second &&
	test_commit third &&
	git switch -c parallel first &&
	mkdir -p 1/2 &&
	test_commit 1/2/3 &&
	git config uploadPack.allowFilter true &&
	git config uploadPack.allowAnySHA1InWant true
'

test_expect_success 'scalar clone' '
	second=$(git rev-parse --verify second:second.t) &&
	scalar clone "file://$(pwd)" cloned --single-branch &&
	(
		cd cloned/src &&

		git config --get --global --fixed-value maintenance.repo \
			"$(pwd)" &&

		git for-each-ref --format="%(refname)" refs/remotes/origin/ >actual &&
		echo "refs/remotes/origin/parallel" >expect &&
		test_cmp expect actual &&

		test_path_is_missing 1/2 &&
		test_must_fail git rev-list --missing=print $second &&
		git rev-list $second &&
		git cat-file blob $second >actual &&
		echo "second" >expect &&
		test_cmp expect actual
	)
'

SQ="'"
test_expect_success UNZIP 'scalar diagnose' '
	(
		cd cloned/src &&
		scalar diagnose >out &&
		cat out &&
		sed -n "s/.*$SQ\\(.*\\.zip\\)$SQ.*/\\1/p" <out >zip_path &&
		zip_path=$(cat zip_path) &&
		test -n "$zip_path" &&
		unzip -v "$zip_path" &&
		folder=${zip_path%.zip} &&
		test_path_is_missing "$folder" &&
		unzip -p "$zip_path" diagnostics.log >out &&
		test_file_not_empty out
	)
'

test_done