import numpy as np

def qt_scale(qt, qf=50):
    """
    Q-table scaler
    Usage: 
        qt_scale(qt_luma, qf=100) / aan_scale_factors_2d
    """    
    if qf < 50:
        scale = 5000/qf
    else:
        scale = 200 - 2*qf  # 2 - qf/50

    t = np.floor((scale*qt + 50) / 100); 
    t[t < 1] = 1   # Prevent divide by 0 error 
    t[t > 255] = 255   # Prevent overflow
    return t.astype(int)