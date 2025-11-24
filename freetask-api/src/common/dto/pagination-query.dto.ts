import { Transform } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

function toOptionalPositiveInt(value: unknown, max?: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return undefined;
  }

  const intValue = Math.floor(parsed);
  if (typeof max === 'number') {
    return Math.min(intValue, max);
  }

  return intValue;
}

export class PaginationQueryDto {
  @IsOptional()
  @Transform(({ value }) => toOptionalPositiveInt(value, 50))
  @IsInt()
  @Min(0)
  @Max(50)
  limit?: number;

  @IsOptional()
  @Transform(({ value }) => toOptionalPositiveInt(value))
  @IsInt()
  @Min(0)
  offset?: number;
}
