from classifier import *
from dataset import *
from rgbtohsv import *

import torch.nn as nn
from torch.optim import Adam
from torch.utils.data import DataLoader

import sys
import argparse
import itertools

# Param
var = argparse.ArgumentParser()
var.add_argument("--Dataset_Path", type=str, default="./datasets", help="데이터셋 경로 지정")
var.add_argument("--mode", type=str, default="training", help="set dataset mode")
var.add_argument("--epoch", type=int, default=300, help="학습을 진행시킬 총 epoch")
var.add_argument("--epoch_start", type=int, default=0, help="모델을 불러오고 싶은 경우 미리 훈련된 모델의 epoch 수 지정")


args = var.parse_args()
root_path = args.Dataset_Path
mode = args.mode
n_epoch = args.epoch
s_epoch = args.epoch_start


device = torch.device("cuda" if torch.cuda.is_available()==True else "cpu")

ds = CustomDataset(root_dir=root_path, input_list="./", mode="training")
ds_loader = DataLoader(dataset=ds, batch_size=1, shuffle=True, num_workers=8)

cf = extraction_mdl(in_dim=3, out_dim=3)
tc = multi_tone_curve()
optimizer = Adam(itertools.chain(cf.parameters(), tc.parameters()), lr=1e-5, eps=1e-8)



def main():
    @torch.set_grad_enabled
    def create_img(x):
        i_img = torch.tensor(x)
        i_hsv = rgb_to_hsv(i_img)
        wmap = cf(i_hsv)
        cmap = tc(i_hsv)
                
        img_c = wmap * cmap
        img = hsv_to_rgb(img_c)
        return img
    
    
    for epoch in (n_epoch-s_epoch):
        for batch in ds_loader:
            input_img, target_img = batch
            optimizer.zero_grad()
            pred = create_img(input_img)

            mse_loss = nn.MSELoss(reduction='mean')
            tv_loss = customized_tv_loss()

            loss = mse_loss(pred, target_img) + tv_loss(x=pred, y=target_img)

            loss.backward()

            sys.stdout.write(f'epoch : {epoch/(n_epoch-s_epoch)}, loss : {loss.item():.5f}')
        if epoch % 10 == 0:
            cf._save_to_state_dict("./models")




    

    

if __name__ == "__main__":
    main()