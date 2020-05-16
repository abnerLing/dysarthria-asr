import pandas as pd 
import os, shutil
import numpy as np


df = pd.read_excel('local/speaker_data.xlsx', index=['id'])
dic = df.set_index('id').T.to_dict('list')

audio_dir = '/home/abner/ua_audio/audio/'

errors = np.load('local/errors.npy')
for subdir, dirs, files in os.walk(audio_dir):
    for file in files:
        filepath = subdir + os.sep + file
        if file in errors:
            print("removing bad files --> ", file)
            os.remove(filepath)


print("Creating wav.scp, text and utt2spk files for train set, please wait..")
# Get train files
wav_file = open("wav.scp", "w")
text_file = open("text", "w")
utt_file = open("utt2spk", "w")

for subdir, dirs, files in os.walk(audio_dir):
    for file in files:
        filepath = subdir + os.sep + file
        if filepath.endswith('.wav') and file.startswith('C') and file not in errors:
            for i in dic:
                if i in file:
                    name = file[:-4]
                    word = str(dic[i]).strip('[]').strip("''").upper()
                    spk = file.split('_')[0] 
                    
                    wav_file.write(name + " "+ filepath + "\n")
                    text_file.write(name + " " + word + "\n")
                    utt_file.write(name + " " + spk + "\n")

        elif 'B1' in file or 'B3' in file and file not in errors:
            for i in dic:
                if i in file:
                    name = file[:-4]
                    word = str(dic[i]).strip('[]').strip("''").upper()
                    spk = file.split('_')[0] 
                    
                    wav_file.write(name + " "+ filepath + "\n")
                    text_file.write(name + " " + word + "\n")
                    utt_file.write(name + " " + spk + "\n")

wav_file.close()
text_file.close()
utt_file.close()
print("Finished creating train files!")

my_files = ['wav.scp', 'text', 'utt2spk']
for idx in my_files:
    shutil.move(idx, 'data/train/')

print(" ")
print("....")
print("Creating test files....")

wav_file = open("wav.scp", "w")
text_file = open("text", "w")
utt_file = open("utt2spk", "w")
for subdir, dirs, files in os.walk(audio_dir):
    for file in files:
        filepath = subdir + os.sep + file
        if filepath.endswith('.wav') and file.startswith('C') ==False and 'B2' in file and file not in errors:
            for i in dic:
                if i in file:
                    name = file[:-4]
                    word = str(dic[i]).strip('[]').strip("''").upper()
                    spk = file.split('_')[0] 
                    
                    wav_file.write(name + " "+ filepath + "\n")
                    text_file.write(name + " " + word + "\n")
                    utt_file.write(name + " " + spk + "\n")


wav_file.close()
text_file.close()
utt_file.close()
for idx in my_files:
    shutil.move(idx, 'data/test/')
print("finished creating all files!")
