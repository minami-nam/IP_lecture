from classifier import *
from dataset import *
from rgbtohsv import *

import torchvision.utils as vutils
from torch.optim import Adam
from torch.utils.data import DataLoader

import sys
import argparse
import itertools

# Param
var = argparse.ArgumentParser()
var.add_argument("--Dataset_Path", type=str, default="./datasets", help="데이터셋 경로 지정")
var.add_argument("--mode", type=str, default="inference", help="set dataset mode")
var.add_argument("--epoch_start", type=int, default=200, help="학습 모델 파일 선택")


args = var.parse_args()
root_path = args.Dataset_Path
mode = args.mode
s_epoch = args.epoch_start


device = torch.device("cuda" if torch.cuda.is_available()==True else "cpu")

ds = CustomDataset(root_dir=root_path, mode="inference")
ds_loader = DataLoader(dataset=ds, batch_size=1, shuffle=False, num_workers=10)

em = extraction_mdl(in_dim=2, out_dim=2).to(device)
# ed = extraction_detail(in_dim=2, out_dim=2).to(device)
gn = gaussian_net().to(device)
cc = color_curve().to(device)
cd = combine_detail().to(device)



sys.stdout.write(f'학습한 모델 및 옵티마이저의 {s_epoch} ckpt 파일을 불러오는 중입니다.')
ckpt_path = f"./saved_models/tone_curve_ckpt_{s_epoch}.ckpt"
load_ckpt = torch.load(ckpt_path)

em.load_state_dict(load_ckpt['em_state_dict'])
# ed.load_state_dict(load_ckpt['ed_state_dict'])
cc.load_state_dict(load_ckpt['cc_state_dict'])
cd.load_state_dict(load_ckpt['cd_state_dict'])
gn.load_state_dict(load_ckpt['gn_state_dict'])

s_epoch = load_ckpt['epoch']
sys.stdout.write(f'불러오기 성공! {s_epoch}을 사용하여 inference를 진행합니다.')

def main():
    @torch.no_grad
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
        return img

    for batch in ds_loader:
        inf_img, inf_name  = batch
        inf_img = inf_img.to(device)
        prev = create_img(inf_img)

        vutils.save_image(prev, f"./saved_results/{inf_name}.png")

        sys.stdout.write(f'\r{inf_name} 저장 완료 !')
        sys.stdout.flush()
    
    sys.stdout.write('Inference가 종료됩니다.')
if __name__ == "__main__":
    main()