#!/bin/bash
. ./path.sh || exit 1
. ./cmd.sh || exit 1
nj=43

decode_nj=15
thread_nj=1

boost_sil=1.25
cmvn_opts="--norm-means=false --norm-vars=false"    # set both false if online mode
sp_opts="--left-context=10 --right-context=10"
numLeavesTri1=1000
numGaussTri1=10000
numLeavesMLLT=1000
numGaussMLLT=10000
numLeavesSAT=1000
numGaussSAT=15000

home_dir=/home/abner/kaldi/egs/uaspeech
data_dir=$home_dir/data  
feat_dir=$home_dir/mfcc
exp_dir=$home_dir/exp
lang=$data_dir/lang



feadir=pitch
steps/make_pitch.sh --nj $nj --cmd "$train_cmd" data/train exp/make_pitch/train $feadir
steps/make_pitch.sh --nj 15 --cmd "$train_cmd" data/test exp/make_pitch/test $feadir
steps/make_pitch.sh --nj 2 --cmd "$train_cmd" data/valid exp/make_pitch/valid $feadir

# Making cmvn.scp files
steps/compute_cmvn_stats.sh data/train exp/make_pitch/train $feadir
steps/compute_cmvn_stats.sh data/test exp/make_pitch/test $feadir
steps/compute_cmvn_stats.sh data/valid exp/make_pitch/valid $feadir




# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1
# Removing previously created data (from last run.sh execution)
#rm -rf exp mfcc data/train/spk2utt data/train/cmvn.scp data/train/feats.scp data/train/split1 data/test/spk2utt data/test/cmvn.scp data/test/feats.scp data/test/split1 data/local/lang data/lang data/local/tmp data/local/dict/lexiconp.txt

#utils/data/perturb_data_dir_speed_3way.sh data/train data/train_sp
d=0
if [ $d == 1 ]; then 
    echo
    echo "===== PREPARING ACOUSTIC DATA ====="
    echo
    # Needs to be prepared by hand (or using self written scripts):
    #
    # spk2gender  [<speaker-id> <gender>]
    # wav.scp     [<uterranceID> <full_path_to_audio_file>]
    # text        [<uterranceID> <text_transcription>]
    # utt2spk     [<uterranceID> <speakerID>]
    # corpus.txt  [<text_transcription>]
    # Making spk2utt files
    #utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
    #utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
    #utils/utt2spk_to_spk2utt.pl data/valid/utt2spk > data/valid/spk2utt

    echo
    echo "===== FEATURES EXTRACTION ====="
    echo
    # Making feats.scp files
    mfccdir=mfcc
    # Uncomment and modify arguments in scripts below if you have any problems with data sorting
    #utils/validate_data_dir.sh data/train     # script for checking prepared data - here: for data/train directory
    #utils/fix_data_dir.sh data/train          # tool for data proper sorting if needed - here: for data/train directory
    #utils/validate_data_dir.sh data/test    
    #utils/fix_data_dir.sh data/test     
    utils/validate_data_dir.sh data/valid
    utils/fix_data_dir.sh data/valid 




    #steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
    #steps/make_mfcc.sh --nj 15 --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir
    steps/make_mfcc.sh --nj 2 --cmd "$train_cmd" data/valid exp/make_mfcc/valid $mfccdir

    # Making cmvn.scp files
    #steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
    #steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir
    steps/compute_cmvn_stats.sh data/valid exp/make_mfcc/valid $mfccdir

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
    # decode 
    #utils/mkgraph.sh $lang $exp_dir/train/tri3 $exp_dir/train/tri3/graph   
    #if [ ! -f $exp_dir/train/tri3/decode_test/scoring_kaldi/best_wer ]; then    
    #   steps/decode.sh --nj $decode_nj --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
    #        $exp_dir/train/tri3/graph $data_dir/test $exp_dir/train/tri3/decode_test
    #
     #  steps/decode.sh --nj $2 --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
     #      $exp_dir/train/tri3/graph $data_dir/valid $exp_dir/train/tri3/decode_valid

    # fi  

    # decode + SAT
    #utils/mkgraph.sh $lang $exp_dir/train/tri4 $exp_dir/train/tri4/graph
    #steps/decode_fmllr.sh --config conf/decode.config --nj 15 --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
	#    $exp_dir/train/tri4/graph $data_dir/test $exp_dir/train/tri4/decode_test
        
    steps/decode_fmllr.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
           $exp_dir/train/tri4/graph $data_dir/valid $exp_dir/train/tri4/decode_valid
    echo "Test WER"
    cat exp/train/tri4/decode_test/scoring_kaldi/best_wer   
    echo "Valid WER"
    cat exp/train/tri4/decode_valid/scoring_kaldi/best_wer   

fi 


gmmdir=$exp_dir/train/tri4
dnndir=$exp_dir/train/dnn
data_fmllr=$dnndir/fmllr-tri4

d=0
if [ $d == 1 ]; then    
    steps/nnet/make_fmllr_feats.sh --nj 15 --cmd "$train_cmd" --transform-dir $gmmdir/decode_test \
        $data_fmllr/test $data_dir/test $gmmdir $data_fmllr/test/log $data_fmllr/test/data || exit 1
    
    steps/nnet/make_fmllr_feats.sh --nj 2 --cmd "$train_cmd" --transform-dir $gmmdir/decode_valid \
        $data_fmllr/valid $data_dir/valid $gmmdir $data_fmllr/valid/log $data_fmllr/valid/data || exit 1
    
    steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
        $data_dir/train $lang ${gmmdir} ${gmmdir}_ali || exit 1;
    
    
    steps/nnet/make_fmllr_feats.sh --nj $nj --cmd "$train_cmd" --transform-dir ${gmmdir}_ali \
        $data_fmllr/train $data_dir/train $gmmdir $data_fmllr/train/log $data_fmllr/train/data || exit 1

    steps/compute_cmvn_stats.sh data/train exp/make_fmllr/train exp/train/dnn/fmllr-tri4/train/data
    steps/compute_cmvn_stats.sh data/test exp/make_fmllr/test exp/train/dnn/fmllr-tri4/test/data
    steps/compute_cmvn_stats.sh data/valid exp/make_fmllr/valid exp/train/dnn/fmllr-tri4/valid/data
   

fi 


d=0
if [ $d == 1 ]; then    
    steps/align_fmllr.sh --nj 15 --cmd "$train_cmd" --boost-silence $boost_sil \
            $data_dir/test $lang ${gmmdir} exp/tri4_ali_test || exit 1;
    steps/align_fmllr.sh --nj 2 --cmd "$train_cmd" --boost-silence $boost_sil \
            $data_dir/valid $lang ${gmmdir} exp/tri4_ali_valid || exit 1;
    steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" --boost-silence $boost_sil \
            $data_dir/train $lang ${gmmdir} exp/tri4_ali_train || exit 1;

    
fi  

