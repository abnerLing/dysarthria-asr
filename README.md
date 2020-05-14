# UASpeech baseline kaldi script
## Note that this repository is not yet complete and I'm still working on it!

This is just a basic script for building a GMM-HMM based ASR with kaldi.
The script is similar to https://github.com/ffxiong/uaspeech and uses the exact same LM method but a few differences with the acoustic model training.

###### For example:
  - Included double delta training before applying lda_mllt training.
  - Speed and tempo augmentation options. 
  - Data preparation using python not bash.
  - Allowed the testing of different context windows.
  
  ## Results
  - Given the stochastic nature of the tasks your results may vary.
  
  Best GMM-HMM WER in [1] --> 44.91% (with re-segmentation) <br/>
  Best WER w/o augmentation --> %WER 42.58 [ 10014 / 23517, 0 ins, 1 del, 10013 sub ]exp/train/tri4/decode_test/wer_8_0.0 <br/>
  Best WER with augmentation --> %WER 40.57 [ 9541 / 23517, 0 ins, 7 del, 9534 sub ]exp/train/tri4/decode_test/wer_8_0.0
  
  
  ## Individual results for best model
  - The table starts from mild dysarthria and ends with severe dysarthria.
  
| Speaker  | WER (%) |
| -------- | ------- |
| F05  | 8.54  |
| M10  | 7.96  |
| M08  | 15.15  |
| M09  | 16.75  |
| M14  | 14.96  |
| F04  | 33.54  |
| M11  | 33.46  |
| M05  | 34.73  |
| M16  | 41.31  |
| F02  | 52.27  |
| M07  | 42.58  |
| M01  | 79.51  |
| M12  | 76.47  |
| F03  | 74.14  |
| M04  | 94.35  |
| Total  | 40.57  |


## References
[1] F. Xiong, J. Barker, and H. Christensen, "Phonetic Analysis of Dysarthric Speech Tempo and Applications to Robust Personalised Dysarthric Speech Recognition," in IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP), Brighton, UK, May 2019
