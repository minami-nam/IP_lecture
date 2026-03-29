import os
from torch.utils.data import DataLoader, Dataset
from PIL import Image
import torchvision.transforms as transforms
import argparse


# Param
var = argparse.ArgumentParser()
var.add_argument("--Dataset_Path", type=str, default="./datasets", help="데이터셋 경로 지정")
var.add_argument("--mode", type=str, default="training", help="set dataset mode")

args = var.parse_args()
root_path = args.Dataset_Path

class CustomDataset(Dataset):
    def __init__(self, root_dir, mode="training"):
        self.root_dir = root_dir
        # self.input_paths = sorted(os.listdir("./data/input/"))
        # self.target_paths = sorted(os.listdir("./data/target/"))
        self.mode = mode
        self.input_dir = os.path.join(root_dir, "input")
        self.input_paths = sorted(os.listdir(self.input_dir))
        self.transform = transforms.ToTensor()

        if self.mode == "training":
            self.target_dir = os.path.join(root_dir, "target")
            self.target_paths = sorted(os.listdir(self.target_dir))
            

            if len(self.input_paths) != len(self.target_paths):
                raise ValueError("입력 이미지와 정답 이미지의 개수가 일치하지 않습니다!")
                
        elif self.mode == "inference":
            self.inference_dir = os.path.join(root_dir, "inference")
            self.inference_paths = sorted(os.listdir(self.inference_dir))
            
        else:
            raise ValueError("Mode는 'training' 또는 'inference'만 입력 가능합니다.")

    def __len__(self):
        if self.mode == 'training':
            return len(self.input_paths)
        elif self.mode == 'inference':
            return len(self.inference_paths)
    
    def __getitem__(self, idx):
   
        if self.mode == "training":

            input_filename = self.input_paths[idx]
            input_path = os.path.join(self.input_dir, input_filename)
            input_img = Image.open(input_path).convert("RGB")
            input_img = self.transform(input_img)

            target_filename = self.target_paths[idx]
            target_path = os.path.join(self.target_dir, target_filename)
            target_img = Image.open(target_path).convert("RGB")
            target_img = self.transform(target_img)
            
            return input_img, target_img

        elif self.mode == "inference":
            inference_filename = self.inference_paths[idx]
            inference_path = os.path.join(self.inference_dir, inference_filename)
            inference_img = Image.open(inference_path).convert("RGB")
            inference_img = self.transform(inference_img)

            
            
            return inference_img, inference_filename

        
