from classifier import *
from dataset import *
from rgbtohsv import *

import torch.nn as nn
from torch.optim import Adam
# from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader
from torch.utils.tensorboard import SummaryWriter

import sys, os
import argparse
import itertools

# Param
var = argparse.ArgumentParser()
var.add_argument("--Dataset_Path", type=str, default="datasets", help="데이터셋 경로 지정")
var.add_argument("--tensorboard_name", type=str, default="training_viewer")
var.add_argument("--mode", type=str, default="training", help="set dataset mode")
var.add_argument("--epoch", type=int, default=500, help="학습을 진행시킬 총 epoch")
var.add_argument("--epoch_start", type=int, default=0, help="모델을 불러오고 싶은 경우 미리 훈련된 모델의 epoch 수 지정")

top_dir = os.getcwd()
args = var.parse_args()
root_path = os.path.join(top_dir, args.Dataset_Path)
mode = args.mode
tb_name = args.tensorboard_name
n_epoch = args.epoch
s_epoch = args.epoch_start


device = torch.device("cuda" if torch.cuda.is_available()==True else "cpu")

ds = CustomDataset(root_dir=root_path, mode="training")
ds_loader = DataLoader(dataset=ds, batch_size=1, shuffle=True, num_workers=10)

em = extraction_mdl(in_dim=2, out_dim=2).to(device)
# ed = extraction_detail(in_dim=2, out_dim=2).to(device)
gn = gaussian_net().to(device)
cc = color_curve().to(device)
cd = combine_detail().to(device)

optimizer = Adam(itertools.chain(em.parameters(), cc.parameters(), cd.parameters(), gn.parameters()), lr=1e-6, eps=1e-8)
writer = SummaryWriter(f'./runs/{tb_name}')
if s_epoch!=0:
    sys.stdout.write(f'학습한 모델 및 옵티마이저의 {s_epoch} ckpt 파일을 불러오는 중입니다.')
    ckpt_path = f"./saved_models/tone_curve_ckpt_{s_epoch}.ckpt"
    load_ckpt = torch.load(ckpt_path)

    em.load_state_dict(load_ckpt['em_state_dict'])
    # ed.load_state_dict(load_ckpt['ed_state_dict'])
    cc.load_state_dict(load_ckpt['cc_state_dict'])
    cd.load_state_dict(load_ckpt['cd_state_dict'])
    gn.load_state_dict(load_ckpt['gn_state_dict'])
    optimizer.load_state_dict(load_ckpt['optimizer_state_dict'])
    s_epoch = load_ckpt['epoch'] + 1
    sys.stdout.write(f'불러오기 성공! {s_epoch}부터 학습을 재개합니다.')
else:
    sys.stdout.write('모델을 처음부터 학습시킵니다.')

def main():
    @torch.set_grad_enabled(True)
    def create_img(x):
        i_img = x
        if i_img.dim() == 3:
            i_img = i_img.unsqueeze(0) 
        i_hsv = rgb_to_hsv(i_img)
        conv = em(i_hsv[:, 1:3, :, :])
        curve = cc(i_hsv[:, 1:3, :, :], conv)
        gaussian = gn(curve)
        img_c = cd(curve, gaussian)
        img_c = torch.concat((i_hsv[:, 0:1, :, :], img_c), dim=1).to(device)
        

        img = hsv_to_rgb(img_c)
        return img, curve

    for epoch in range(n_epoch):
        for batch_idx, batch in enumerate(ds_loader):
            
            input_img, target_img = batch
            input_img = input_img.to(device)
            target_img = target_img.to(device)

            optimizer.zero_grad()
            pred, curve = create_img(input_img)

        
            ssim_loss = SSIM()
            color_loss = hsv_loss()
            sharpness_loss = grad_loss()
            totalv_loss = tv_loss()
            

            c_loss = color_loss(x=pred, y=target_img) 
            similar_loss = ssim_loss(x=pred, y=target_img)
            s_loss = sharpness_loss(x=pred, y=target_img)
            total_variation_loss = totalv_loss(x=curve)

            loss = c_loss + 8*similar_loss + 10*s_loss + 0.005*total_variation_loss

            loss.backward()
            optimizer.step()


            sys.stdout.write(f'\repoch : {epoch+s_epoch}, batch : {batch_idx}/{len(ds_loader)}, loss : {loss.item():.5f}, c_loss : {c_loss.item():.5f},  grad_loss : {s_loss.item():.5f}, ssim : {similar_loss.item():.5f}, total variation loss : {total_variation_loss.item():.5f}')
            sys.stdout.flush()
            
            writer.add_scalar('Loss/Total', loss.item(), epoch)
            writer.add_scalar('Loss/SSIM', similar_loss.item(), epoch)
            writer.add_scalar('Loss/Color', c_loss.item(), epoch)
            writer.add_scalar('Loss/Grad', s_loss.item(), epoch)
            writer.add_scalar('Loss/TV', total_variation_loss.item(), epoch)      
        if (epoch+s_epoch) % 5 == 0:
            checkpoint = {
                'epoch' : epoch+s_epoch,
                'em_state_dict' : em.state_dict(),
                # 'ed_state_dict' : ed.state_dict(),
                'cc_state_dict' : cc.state_dict(),
                'cd_state_dict' : cd.state_dict(),
                'gn_state_dict' : gn.state_dict(),
                'optimizer_state_dict' : optimizer.state_dict()
            }
            save_path = f"./saved_models/tone_curve_ckpt_{epoch+s_epoch}.ckpt"

            torch.save(checkpoint, save_path)
            sys.stdout.write(f'{epoch+s_epoch} Checkpoint 저장 완료 !')
            sys.stdout.flush()
            
    writer.close()
    

if __name__ == "__main__":
    main()