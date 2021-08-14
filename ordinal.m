function output = ordinal(integer)
            str = num2str(integer);
            
            if strlength(str)<2
                switch(str(end))
                    case '1'
                        output = append(str,'st');
                    case '2'
                        output = append(str,'nd');
                    case '3'
                        output = append(str,'rd');
                    otherwise
                        output = append(str,'th');
                end
            else
                switch(str(end))
                    case '1'
                        switch(str(end-1:end))
                            case '11'
                                output = append(str(1:end-2),'11th');
                            otherwise
                                output = append(str,'st');
                        end
                    case '2'
                        switch(str(end-1:end))
                            case '12'
                                output = append(str(1:end-2),'12th');
                            otherwise
                                output = append(str,'nd');
                        end
                    case '3'
                        switch(str(end-1:end))
                            case '13'
                                output = append(str(1:end-2),'13th');
                            otherwise
                                output = append(str,'rd');
                        end
                    otherwise
                        output = append(str,'th');
                end
            end
        end