import torch

def rgb_to_hsv(x_rgb: torch.Tensor): 

    r = x_rgb[:, 0:1, :, :] / 255.0
    g = x_rgb[:, 1:2, :, :] / 255.0
    b = x_rgb[:, 2:3, :, :] / 255.0

    cmax = torch.maximum(r, torch.maximum(g, b))
    cmin = torch.minimum(r, torch.minimum(g, b))

    delta = cmax - cmin + 1e-8


    h_r = 60.0 * ((g - b) / delta)
    h_g = 60.0 * (((b - r) / delta) + 2.0)
    h_b = 60.0 * (((r - g) / delta) + 4.0)

    h = torch.zeros_like(cmax) 
    h = torch.where(cmax == b, h_b, h)
    h = torch.where(cmax == g, h_g, h)
    h = torch.where(cmax == r, h_r, h)
    

    h = torch.where(h < 0.0, (h + 360.0) / 360.0, h / 360.0)


    s = torch.where(cmax == 0.0, torch.zeros_like(cmax), delta / (cmax + 1e-8))


    v = cmax

    
    return torch.concat((h,s,v), dim=1)


def hsv_to_rgb(x_hsv: torch.Tensor):
    h = x_hsv[:, 0:1, :, :] * 360.0
    s = x_hsv[:, 1:2, :, :]
    v = x_hsv[:, 2:3, :, :]

    c = s * v
    mid = c * (1.0 - torch.abs(((h / 60.0) % 2.0) - 1.0))
    m = v - c


    mask0 = (h >= 0.0) & (h < 60.0)
    mask1 = (h >= 60.0) & (h < 120.0)
    mask2 = (h >= 120.0) & (h < 180.0)
    mask3 = (h >= 180.0) & (h < 240.0)
    mask4 = (h >= 240.0) & (h < 300.0)
    mask5 = (h >= 300.0) # else 에 해당


    z = torch.zeros_like(h)


    r = torch.where(mask0 | mask5, c, z)
    r = torch.where(mask1 | mask4, mid, r)
    r = torch.where(mask2 | mask3, z, r) 


    g = torch.where(mask1 | mask2, c, z)
    g = torch.where(mask0 | mask3, mid, g)
    g = torch.where(mask4 | mask5, z, g)

    b = torch.where(mask3 | mask4, c, z)
    b = torch.where(mask2 | mask5, mid, b)
    b = torch.where(mask0 | mask1, z, b)

    r = (r + m) * 255.0
    g = (g + m) * 255.0
    b = (b + m) * 255.0

    rgb = torch.cat((r, g, b), dim=1)
    return rgb