import torch
import torch.nn as nn
from rgbtohsv import rgb_to_hsv
import torchvision.transforms.functional as TF
import torch.nn.functional as F


## 모델 구성 관련 
class extraction_mdl(nn.Module):
    def __init__(self, in_dim=3, out_dim=3):
        super().__init__()
        self.in_dim=in_dim
        self.out_dim=out_dim

        self.layer = nn.Sequential(
            *layer_extract(in_dim, 8),
            *layer_extract(8,16),
            *layer_extract(16,32),
            *layer_extract(32,64),
            nn.Conv2d(64, 64, 3, padding=2, groups=2, dilation=2),
            nn.LeakyReLU(0.2),
            nn.Conv2d(64, kernel_size=3, padding=2, out_channels=out_dim, groups=2, dilation=2)  # 3
        )

    def forward(self, x):
        res = self.layer(x)
        return res
    

def layer_extract(in_dim, out_dim):
    layer = [
        nn.Conv2d(in_dim, out_dim, 3, padding=1, groups=2),
        nn.LeakyReLU(0.2),
    ]
    return layer

class extraction_detail(nn.Module):
    def __init__(self, in_dim=3, out_dim=3):
        super().__init__()       
        self.layer = nn.Sequential(
            nn.Conv2d(in_channels=in_dim, out_channels=16, kernel_size=1, groups=2),
            nn.LeakyReLU(0.2),
            nn.Conv2d(in_channels=16, out_channels=out_dim, kernel_size=1, groups=2),
            nn.BatchNorm2d(num_features=2)
        )
    def forward(self, x):
        res = self.layer(x)
        return res
    
class decomposition(nn.Module):
    def __init__(self):
        super().__init__()  
        self.layer = nn.Sequential(
            nn.AvgPool2d(3,1,1),
            nn.AvgPool2d(3,1,1),
            nn.AvgPool2d(3,1,1),
            nn.AvgPool2d(3,1,1),
            nn.AvgPool2d(3,1,1),
        )

    def forward(self, x):
        lo_freq = self.layer(x)
        hi_freq = x - self.layer(x)
        return lo_freq, hi_freq
    
class gaussian_net(nn.Module):
    def __init__(self):
        super().__init__()
    def forward(self, x : torch.tensor):
        gaussian = TF.gaussian_blur(x, kernel_size=3, sigma=0.8)
        gaussian_hi_map = x - gaussian
        return gaussian_hi_map

    
class color_curve(nn.Module):
    def __init__(self):
        super().__init__()
        self.w1 = nn.Parameter(torch.tensor(1.0))
        self.w2 = nn.Parameter(torch.tensor(1.0))
        self.w3 = nn.Parameter(torch.tensor(1.0))
        self.w4 = nn.Parameter(torch.tensor(1.0))

    def forward(self, original_sv, curve_params):
        # S용 커브 파라미터와 V용 커브 파라미터 분리
        alpha_s = curve_params[:, 0:1, :, :]
        alpha_v = curve_params[:, 1:2, :, :]
        
        original_s = original_sv[:, 0:1, :, :]
        original_v = original_sv[:, 1:2, :, :]
        
        enhanced_s = original_s + alpha_s * original_s * (1.0 - original_s)
        enhanced_v = original_v + alpha_v * original_v * (1.0 - original_v)
        
        return torch.cat([enhanced_s, enhanced_v], dim=1)


class combine_detail(nn.Module):
    def __init__(self):
        super().__init__()
        self.w1 = nn.Parameter(torch.tensor(1.0))
        self.w2 = nn.Parameter(torch.tensor(0.1))
        
   
    def forward(self, conv, hi):
        res = self.w1*conv + self.w2*hi

        return res

class noise_reduction(nn.Module):
    def __init__(self):
        super().__init__()
        self.w1 = nn.Parameter(torch.tensor(0.98))
        self.denoise = nn.AvgPool2d(3, 1, 1)
        self.conv = nn.Conv2d(in_channels=2, out_channels=2, kernel_size=3, stride=1, padding=1, groups=2)
        self.relu = nn.LeakyReLU(0.1)
        
    def forward(self, x):
        avg = self.denoise(x)
        avg = self.conv(avg)
        avg = self.relu(avg)
        diff = x-avg
        denoise = self.w1*x + (1-self.w1)*diff
        return denoise
    
    
    
## Loss 관련

class hsv_loss(nn.Module):
    def __init__(self):
        super().__init__()
    def forward(self, x, y):
        hsv_x = rgb_to_hsv(x)
        hsv_y = rgb_to_hsv(y)

        # diff_h = torch.max(torch.abs(hsv_x[:, 0:1, :, :] - hsv_y[:, 0:1, :, :]))
        diff_s = torch.mean(torch.abs(hsv_x[:, 1:2, :, :] - hsv_y[:, 1:2, :, :]))
        diff_v = torch.mean(torch.abs(hsv_x[:, 2:3, :, :] - hsv_y[:, 2:3, :, :]))

        loss = 8.5*diff_s + 5*diff_v
        return loss

class SSIM(nn.Module):
    """Layer to compute the SSIM loss between a pair of images
    """
    def __init__(self):
        super(SSIM, self).__init__()
        self.mu_x_pool   = nn.AvgPool2d(3, 1)
        self.mu_y_pool   = nn.AvgPool2d(3, 1)
        self.sig_x_pool  = nn.AvgPool2d(3, 1)
        self.sig_y_pool  = nn.AvgPool2d(3, 1)
        self.sig_xy_pool = nn.AvgPool2d(3, 1)

        # 입력 경계의 반사를 사용하여 상/하/좌/우에 입력 텐서를 추가로 채웁니다.
        self.refl = nn.ReflectionPad2d(1)

        self.C1 = 0.01 ** 2
        self.C2 = 0.03 ** 2

    def forward(self, x, y):
        x = self.refl(x) 
        y = self.refl(y)

        mu_x = self.mu_x_pool(x)
        mu_y = self.mu_y_pool(y)

        sigma_x  = self.sig_x_pool(x ** 2) - mu_x ** 2
        sigma_y  = self.sig_y_pool(y ** 2) - mu_y ** 2
        sigma_xy = self.sig_xy_pool(x * y) - mu_x * mu_y

        SSIM_n = (2 * mu_x * mu_y + self.C1) * (2 * sigma_xy + self.C2)
        SSIM_d = (mu_x ** 2 + mu_y ** 2 + self.C1) * (sigma_x + sigma_y + self.C2)

        loss = 1 - (SSIM_n/SSIM_d)
        return torch.mean(loss)
    
class grad_loss(nn.Module):
    def __init__(self):
        super().__init__()
        
    def forward(self, x, y):
        dx1 = x[:, 1:3, 1:, :] - x[:, 1:3, :-1, :]
        dx2 = x[:, 1:3, :, 1:] - x[:, 1:3, :, :-1]
        
        dy1 = y[:, 1:3, 1:, :] - y[:, 1:3, :-1, :]
        dy2 = y[:, 1:3, :, 1:] - y[:, 1:3, :, :-1]
    
        dh1 = torch.mean(torch.abs(dx1-dy1))
        dh2 = torch.mean(torch.abs(dx2-dy2))
        
        return dh1+dh2