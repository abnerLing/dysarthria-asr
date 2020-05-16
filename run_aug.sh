#!/bin/bash
#!/bin/python3
. ./path.sh || exit 1
. ./cmd.sh || exit 1
. utils/parse_options.sh || exit 1

stage=1
train_nj=43  # you can lower the number if you don't have enough processors
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

home_dir=/home/user/kaldi/egs/uaspeech_github	# change to your directory
data_dir=$home_dir/data  
feat_dir=$home_dir/mfcc
exp_dir=$home_dir/exp
lang=$data_dir/lang
flist_dir=$home_dir/local/flist




if [ $stage -le 1 ]; then
	rm -r data/train
	rm -r data/test
	rm -r data/train_sp
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
	echo "--Creating speed augmented data --"
	echo
    	
	for x in train test ; do
		utils/validate_data_dir.sh data/$x
		utils/fix_data_dir.sh data/$x          
	done
	
	# Same as the 3way script except I removed the 0.9 speed option
    	local/perturb_data_dir_speed_1way.sh data/train data/train_sp
	utils/validate_data_dir.sh data/train_sp
	utils/fix_data_dir.sh data/train_sp   
	
	# this removes the augmentation applied to healthy speakers
	for x in wav.scp text utt2spk reco2dur spk2utt utt2dur utt2uniq ; do
		sed -i '/sp1.1-C/d' $data_dir/train_sp/$x 
	done

	echo
	echo "--extracting MFCC--"	
	echo
	
	mfccdir=mfcc
	steps/make_mfcc.sh --nj $train_nj --cmd "$train_cmd" data/train_sp exp/make_mfcc/train_sp $mfccdir
    	steps/make_mfcc.sh --nj $test_nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir
    
    	# Making cmvn.scp files
    	for x in train_sp test ; do
		steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
       
	done

fi    

if [ $stage -le 4 ]; then
	
	## Monophone training and alignment
	steps/train_mono.sh --nj $train_nj --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
	      	$data_dir/train_sp $lang $exp_dir/train_sp/mono
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train_sp $lang $exp_dir/train_sp/mono $exp_dir/train_sp/mono_ali
	
	## Delta and delta-delta training and alignment
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train_sp $lang $exp_dir/train_sp/mono_ali $exp_dir/train_sp/tri1
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train_sp $lang $exp_dir/train_sp/tri1 $exp_dir/train_sp/tri1_ali
	steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train_sp $lang $exp_dir/train_sp/tri1_ali $exp_dir/train_sp/tri2
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train_sp $lang $exp_dir/train_sp/tri2 $exp_dir/train_sp/tri2_ali
	
	## LDA-MLLT train/aign (Linear Discriminant Analysis – Maximum Likelihood Linear Transform)
	steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "$cmvn_opts" --splice_opts "$sp_opts" --boost-silence $boost_sil \
		$numLeaves $numGauss $data_dir/train_sp $lang $exp_dir/train_sp/tri2_ali $exp_dir/train_sp/tri3
	steps/align_si.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train_sp $lang $exp_dir/train_sp/tri3 $exp_dir/train_sp/tri3_ali
	
	## SAT training with fmllr alignment 
	steps/train_sat.sh --cmd "$train_cmd" --boost-silence $boost_sil \
		$numLeavesSAT $numGaussSAT $data_dir/train_sp $lang $exp_dir/train_sp/tri3_ali $exp_dir/train_sp/tri4
	steps/align_fmllr.sh --nj $train_nj --cmd "$train_cmd" --boost-silence $boost_sil \
		$data_dir/train_sp $lang $exp_dir/train_sp/tri4 $exp_dir/train_sp/tri4_ali

fi


if [ $stage -le 5 ]; then
	# Decoding tri4 (SAT) alignments
	utils/mkgraph.sh $lang $exp_dir/train_sp/tri4 $exp_dir/train_sp/tri4/graph
	steps/decode_fmllr.sh --config conf/decode.config --nj $test_nj --cmd "$decode_cmd"  --num-threads $thread_nj --scoring_opts "$scoring_opts" \
		$exp_dir/train_sp/tri4/graph $data_dir/test $exp_dir/train_sp/tri4/decode_test
        
    	echo "Best test WER"
    	cat exp/train_sp/tri4/decode_test/scoring_kaldi/best_wer   

fi 

