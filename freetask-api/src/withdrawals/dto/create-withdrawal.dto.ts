import { IsNumber, IsPositive, IsObject } from 'class-validator';

export class CreateWithdrawalDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsObject()
  bankDetails: {
    accountName: string;
    accountNumber: string;
    bankName: string;
    [key: string]: any;
  };
}
