import torch
import torch.nn as nn


class extraction_mdl(nn.Module):
    def __init__(self, in_dim=3, out_dim=3):
        super().__init__()
        self.in_dim=in_dim
        self.out_dim=out_dim
        
        self.layer = nn.Sequential(
            *layer_extract(in_dim, 8),
            *layer_extract(8,16),
            *layer_extract(16,32),
            nn.Conv2d(32,kernel_size=3, padding=1, out_channels=out_dim)  # 3
        )
    def forward(self, x):
        res = self.layer(x)
        return res

def layer_extract(in_dim, out_dim):
    layer = [
        nn.Conv2d(in_dim, out_dim, 3, padding=1),
        nn.LeakyReLU(0.02),
        nn.BatchNorm2d(num_features=out_dim)
    ]
    return layer




class multi_tone_curve(nn.Module):
    def __init__(self):
        super().__init__()
        self.w1 = nn.Parameter(torch.tensor(1.0))
        self.w2 = nn.Parameter(torch.tensor(1.0))
        self.r1 = nn.Parameter(torch.tensor(0.05)) 
        self.r2 = nn.Parameter(torch.tensor(0.05))
    def forward(self, x):
        h = x[:, 0:1, :, :]
        s = x[:, 1:2, :, :]
        v = x[:, 2:3, :, :]
        ratio_w1 = 1.0 - torch.tanh(s-self.w1)
        ratio_w2 = 1.0 - torch.tanh(v-self.w2)

        updated_h = h
        updated_s = (0.25+ratio_w1)*s + self.r1
        updated_v = (0.25+ratio_w2)*v + self.r2

         

        return updated_h, updated_s, updated_v
    
class customized_tv_loss(nn.Module):
    def __init__(self):
        super().__init__()
    def forward(self, x, y):
        d1 = x[:, :, :, :-1] - x[:, :, :, 1:]
        d2 = x[:, :, :-1, :] - x[:, :, :1, :]
        
        t1 = y[:, :, :, :-1] - y[:, :, :, 1:]
        t2 = y[:, :, :-1, :] - y[:, :, :1, :] 
        value = (torch.mean(torch.abs(d1-t1)) + torch.mean(torch.abs(d2-t2)))/2
        return value

