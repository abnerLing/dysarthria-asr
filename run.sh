#!/bin/bash
. ./path.sh || exit 1
. ./cmd.sh || exit 1
nj=$nj

decode_nj=15

boost_sil=1.25
cmvn_opts="--norm-means=false --norm-vars=false"    # set both false if online mode
sp_opts="--left-context=10 --right-context=10"
numLeavesTri1=1000
numGaussTri1=10000
numLeavesMLLT=1000
numGaussMLLT=10000
numLeavesSAT=1000
numGaussSAT=15000

home_dir=/home/user/kaldi/egs/uaspeech
data_dir=$home_dir/data  
feat_dir=$home_dir/mfcc
exp_dir=$home_dir/exp
lang=$data_dir/lang


#utils/data/perturb_data_dir_speed_3way.sh data/train data/train_sp
d=0
if [ $d == 1 ]; then 
    echo
    echo "===== PREPARING ACOUSTIC DATA ====="
    echo

    #utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
    #utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

    echo
    echo "===== FEATURES EXTRACTION ====="
    echo
    # Making feats.scp files
    mfccdir=mfcc
    # Uncomment and modify arguments in scripts below if you have any problems with data sorting
    utils/validate_data_dir.sh data/train     # script for checking prepared data - here: for data/train directory
    utils/fix_data_dir.sh data/train          # tool for data proper sorting if needed - here: for data/train directory
    utils/validate_data_dir.sh data/test    
    utils/fix_data_dir.sh data/test     





    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
    steps/make_mfcc.sh --nj 15 --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir

    # Making cmvn.scp files
    steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
    steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

fi    


d=0
if [ $d == 1 ]; then
	steps/train_mono.sh --nj $nj --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
	      	$data_dir/train $lang $exp_dir/train/mono
	steps/align_si.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/mono $exp_dir/train/mono_ali
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeavesTri1 $numGaussTri1 $data_dir/train $lang $exp_dir/train/mono_ali $exp_dir/train/tri1
	steps/align_si.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri1 $exp_dir/train/tri1_ali
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeavesTri1 $numGaussTri1 $data_dir/train $lang $exp_dir/train/tri1_ali $exp_dir/train/tri2
	steps/align_si.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri2 $exp_dir/train/tri2_ali
	steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --splice_opts "$sp_opts" --boost-silence $boost_sil \
		$numLeavesMLLT $numGaussMLLT $data_dir/train $lang $exp_dir/train/tri2_ali $exp_dir/train/tri3
	steps/align_si.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri3 $exp_dir/train/tri3_ali
	steps/train_sat.sh --cmd "$train_cmd" --boost-silence $boost_sil \
		$numLeavesSAT $numGaussSAT $data_dir/train $lang $exp_dir/train/tri3_ali $exp_dir/train/tri4
	steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train $lang $exp_dir/train/tri4 $exp_dir/train/tri4_ali

fi
  
d=0
if [ $d == 1 ]; then    
    # decode SAT
    utils/mkgraph.sh $lang $exp_dir/train/tri4 $exp_dir/train/tri4/graph
    steps/decode_fmllr.sh --config conf/decode.config --nj 15 --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
	    $exp_dir/train/tri4/graph $data_dir/test $exp_dir/train/tri4/decode_test

    echo "Test WER"
    cat exp/train/tri4/decode_test/scoring_kaldi/best_wer    

fi 
