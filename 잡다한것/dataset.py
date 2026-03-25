import torch
from torch.utils.data import DataLoader, Dataset
from PIL import Image, ImageCms
from pathlib import Path
import argparse


# Param
var = argparse.ArgumentParser()
var.add_argument("--Dataset_Path", type=str, default="./datasets", help="데이터셋 경로 지정")
var.add_argument("--mode", type=str, default="training", help="set dataset mode")

args = var.parse_args()
root_path = args.Dataset_Path

class CustomDataset(Dataset):
    def __init__(self, root_dir, input_list, mode):
        self.root_dir = root_dir
        self.list = Path.open(f"{root_dir}/{input_list}", "r")
        self.mode = mode

    def __len__(self):
        return len(self.list)
    
    def __getitem__(self, idx):
        input_path = Path.joinpath(self.root_dir, f"input/input_img_{idx}.jpg")
        input_img = Image.open(input_path).convert("RGB")
        

        if (self.mode=="training"):
            target_path = Path.joinpath(self.root_dir, f"target/target_img_{idx}.jpg")
            target_img = Image.open(target_path).convert("RGB")
            return input_img, target_img

            
        elif (self.mode=="inference"):
            return input_img, None
            
        else:
           return print("Mode의 이름이 정확하게 입력되었는지 확인하십시오")

        
