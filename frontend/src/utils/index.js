export const daysLeft = (deadline) => {
    const difference = new Date(deadline * 1000).getTime() - Date.now();
    const remainingDays = difference / (1000 * 3600 * 24);

    return remainingDays.toFixed(0);
};

export const yearsLeft = (deadline) => {
    const difference = new Date(deadline * 1000).getTime() - Date.now();
    const remainingYears = difference / (1000 * 3600 * 24 * 365);

    console.log(remainingYears);
    return remainingYears.toFixed(0);
};

export const calculateBarPercentage = (goal, raisedAmount) => {
    const percentage = Math.round((raisedAmount * 100) / goal);

    return percentage;
};

export const checkIfImage = (url, callback) => {
    const img = new Image();
    img.src = url;

    if (img.complete) callback(true);

    img.onload = () => callback(true);
    img.onerror = () => callback(false);
};