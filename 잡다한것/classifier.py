import torch
import torch.nn as nn
import torch.nn.functional as F

class extraction_mdl(nn.Module):
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.in_dim=in_dim
        self.out_dim=out_dim
        
        self.layer = nn.Sequential(
            nn.AdaptiveAvgPool2d((300,300)),
            *layer_extract(in_dim, 8),
            *layer_extract(8,16),
            *layer_extract(16,32),
            nn.Conv2d(32,out_channels=out_dim)
        )
    def forward(self, x):
        res = self.layer(x)
        return res

def layer_extract(in_dim, out_dim):
    layer = [
        nn.Conv2d(in_dim, out_dim,3,padding=1),
        nn.LeakyReLU(0.02),
        nn.BatchNorm2d(num_features=out_dim)
    ]
    return layer