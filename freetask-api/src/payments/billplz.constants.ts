export const BILLPLZ_BANK_CODES = [
  'MBBEMYKL', // Maybank
  'CIMB', // CIMB Bank
  'RHB', // RHB Bank
  'PBB', // Public Bank
  'HLB', // Hong Leong Bank
  'AMB', // AmBank
  'BIMB', // Bank Islam
  'BKRM', // Bank Kerjasama Rakyat Malaysia
  'BMMB', // Bank Muamalat
  'BSN', // Bank Simpanan Nasional
  'AFFIN', // Affin Bank
  'ABMB', // Alliance Bank
  'AGRO', // Agro Bank
  'ALRAJHI', // Al Rajhi Bank
  'BANKRAKYAT', // Bank Rakyat
  'BOCM', // Bank of China
  'CITI', // Citibank
  'DB', // Deutsche Bank
  'HSBC', // HSBC Bank
  'ILL', // Industrial & Commercial Bank of China
  'KFH', // Kuwait Finance House
  'MBSB', // MBSB Bank
  'OCBC', // OCBC Bank
  'SC', // Standard Chartered
  'UOB', // UOB Bank
];

export const isValidBankCode = (code: string): boolean => {
  // Some codes might be just prefix in our system vs full swift/id in Billplz.
  // This list attempts to cover common ones used in Malaysia.
  // Ideally we should use the exact list from https://www.billplz.com/api#bank-codes-list
  return BILLPLZ_BANK_CODES.includes(code);
};
