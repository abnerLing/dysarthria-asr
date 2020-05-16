#!/bin/bash
#!/bin/python3

. ./path.sh || exit 1
. ./cmd.sh || exit 1
. utils/parse_options.sh || exit 1

stage=1
train_nj=28  # you can lower the number if you don't have enough processors
test_nj=15

thread_nj=1
decode_nj=15
boost_sil=1.25
cmvn_opts="--norm-means=false --norm-vars=false"    
sp_opts="--left-context=10 --right-context=10"
numLeaves=1000
numGauss=10000
numLeavesSAT=1000
numGaussSAT=15000

home_dir=/home/user/kaldi/egs/uaspeech_github 	# change to your directory 
data_dir=$home_dir/data  
feat_dir=$home_dir/mfcc
exp_dir=$home_dir/exp
lang=$data_dir/lang
flist_dir=$home_dir/local/flist



if [ $stage -le 1 ]; then
	rm -r /data/train
	rm -r /data/test
	echo
	echo "---Prepaing UAspeech data and directories---"
	echo
	mkdir -p $data_dir/train
	mkdir -p $data_dir/test
	python $home_dir/local/prepare_ua_data.py
	utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
	utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
fi

if [ $stage -le 2 ]; then
	# generate uni grammer for UASPEECH in data/lang
	if [ ! -f $data_dir/lang/G.fst ]; then
		local/prepare_uaspeech_lang.sh $flist_dir $data_dir || exit 1;
	fi
fi


if [ $stage -le 3 ]; then
	echo
    	echo "===== FEATURES EXTRACTION ====="
    	echo
    	mfccdir=mfcc
    	utils/validate_data_dir.sh data/train     
    	utils/fix_data_dir.sh data/train          
    	utils/validate_data_dir.sh data/test    
    	utils/fix_data_dir.sh data/test     

    	steps/make_mfcc.sh --nj $train_nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
    	steps/make_mfcc.sh --nj $test_nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir
    
    	# Making cmvn.scp files
    	steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
    	steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

fi    

if [ $stage -le 4 ]; then
	
	## Monophone training and alignment
	steps/train_mono.sh --nj $train_nj --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
	      	$data_dir/train $lang $exp_dir/train/mono
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/mono $exp_dir/train/mono_ali
	
	## Delta and delta-delta training and alignment
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train $lang $exp_dir/train/mono_ali $exp_dir/train/tri1
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri1 $exp_dir/train/tri1_ali
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train $lang $exp_dir/train/tri1_ali $exp_dir/train/tri2
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri2 $exp_dir/train/tri2_ali
	
	## LDA-MLLT train/aign (Linear Discriminant Analysis – Maximum Likelihood Linear Transform)
	steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --splice_opts "$sp_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train $lang $exp_dir/train/tri2_ali $exp_dir/train/tri3
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri3 $exp_dir/train/tri3_ali
	
	## SAT training with fmllr alignment 
	steps/train_sat.sh --cmd "$train_cmd" --boost-silence $boost_sil \
		$numLeavesSAT $numGaussSAT $data_dir/train $lang $exp_dir/train/tri3_ali $exp_dir/train/tri4
	steps/align_fmllr.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri4 $exp_dir/train/tri4_ali

fi


if [ $stage -le 5 ]; then
	# Decoding tri4 (SAT) alignments
	utils/mkgraph.sh $lang $exp_dir/train/tri4 $exp_dir/train/tri4/graph
	steps/decode_fmllr.sh --config conf/decode.config --nj $test_nj --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
		$exp_dir/train/tri4/graph $data_dir/test $exp_dir/train/tri4/decode_test
        
    	echo "Best test WER"
    	cat exp/train/tri4/decode_test/scoring_kaldi/best_wer   

fi 

